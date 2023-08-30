# Multi stage build
# Images:
#  build: build image used to compile oofem (in release mode with python bindings)
#  oofem: plain oofem solver image
#  oofem-python: oofem + python interface+ python
#  oofem-jupyter: oofem + python interface + jupyter notebook server

ARG NB_USER="oofem"
ARG NB_UID="1000"
ARG NB_GID="100"

FROM ubuntu:latest AS ubuntu

# -----------------------------------------------------------------------
# oofem builder image
# -----------------------------------------------------------------------
FROM ubuntu AS build
USER root


ARG NB_USER
ARG NB_UID
ARG NB_GUD
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends build-essential cmake g++ python3 python3-pip python3-dev python3-pytest git && \
    apt-get clean && rm -fr /var/lib/apt/lists/*

WORKDIR /tmp
RUN git clone https://github.com/oofem/oofem.git && \
    cd oofem; git submodule update --init  && \
    mkdir build &&\
    cd build; cmake -DCMAKE_BUILD_TYPE="Release" -DUSE_PYBIND_BINDINGS="ON" .. && \
    make -j 
    
# -------------------------------------------------------------------------
# Basic oofem distribution image
# -------------------------------------------------------------------------
FROM ubuntu AS oofem
ARG NB_USER
ARG NB_UID
ARG NB_GUD
ENV HOME="/home/${NB_USER}"
COPY --from=build /tmp/oofem/build/oofem /bin
COPY --from=build /tmp/oofem/build/liboofem.so /lib
COPY --from=build /tmp/oofem/build/oofempy.so /lib
WORKDIR "${HOME}/oofem-tools"
COPY --from=build /tmp/oofem/tools/extractor.py "${HOME}/oofem-tools"
COPY --from=build /tmp/oofem/tools/unv2oofem "${HOME}/oofem-tools"
RUN useradd --user-group --system --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}"
USER ${NB_USER}
WORKDIR "${HOME}/oofem-tools"
COPY examples/*.in ${HOME}/oofem-examples/
WORKDIR ${HOME}

# -------------------------------------------------------------------------
# oofem-python image
# -------------------------------------------------------------------------
FROM oofem AS oofem-python
ARG NB_USER
ARG NB_UID
ARG NB_GUD
USER root
ENV DEBIAN_FRONTEND noninteractive
ENV PYTHONPATH=/lib
ENV HOME="/home/${NB_USER}"
# Install some packages (libx11 xvfb and libgl1 needed by pyvista)
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends tini python3 python3-dev python3-pip nano && \
    apt-get clean && rm -fr /var/lib/apt/lists/* && \
    pip install --upgrade pip && \
    pip install numpy 
USER ${NB_UID}
WORKDIR ${HOME}

# -------------------------------------------------------------------------
# oofem-jupyter image
# -------------------------------------------------------------------------
FROM oofem-python AS oofem-jupyter
ARG NB_USER
ARG NB_UID
ARG NB_GUD
USER root
ENV HOME="/home/${NB_USER}"
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends libx11-6  libgl1-mesa-glx xvfb libxrender1 && \
    apt-get clean && rm -fr /var/lib/apt/lists/* && \
    pip install pyvista matplotlib  pythreejs itkwidgets && \
    pip install jupyter
#   pip install ipyvtklink ipywidgets

USER ${NB_UID}

RUN mkdir "${HOME}/work" && \
    mkdir "${HOME}/sample-notebooks" && \
    chmod g+rwX "${HOME}/work" "${HOME}/sample-notebooks" 
ENV PYTHONPATH=/lib:${HOME}/sample-notebooks
COPY config/jupyter_notebook_config.py /etc/jupyter
COPY examples/vtkdemo.ipynb ${HOME}/sample-notebooks
COPY examples/running_solver_demo.ipynb ${HOME}/sample-notebooks
COPY examples/util.py ${HOME}/sample-notebooks
COPY examples/Generating_model.ipynb ${HOME}/sample-notebooks
COPY examples/assemble-and-solve.ipynb ${HOME}/sample-notebooks

WORKDIR ${HOME}
RUN jupyter notebook --generate-config

USER root
EXPOSE 8888

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["jupyter", "notebook", "--ip=\"0.0.0.0\""]

USER ${NB_UID}
WORKDIR ${HOME}

# -------------------------------------------------------------------------
# oofem-jupyter image
# -------------------------------------------------------------------------
FROM oofem-python AS oofem-course
ARG SALOME_VERSION=9.11.0
ARG NB_USER
ARG NB_UID
ARG NB_GUD
USER root

ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME="/home/${NB_USER}" \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    NO_VNC_HOME="${HOME}/noVNC" \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

ENV DEBIAN_FRONTEND noninteractive

WORKDIR $HOME

RUN apt-get update

RUN apt-get install -y apt-utils locales language-pack-en language-pack-en-base ; update-locale 

RUN apt-get install -y --no-install-recommends \
    dbus-x11\
    xauth \
    xinit \
    x11-xserver-utils \
    xdg-utils \
    libnss-wrapper \
    software-properties-common \
    xfce4 \
    xfce4-terminal \
    elementary-xfce-icon-theme


RUN apt-get install -y \
    git \
    curl \
    screen \
    wget \
    sudo \
    gpg-agent \
    python3-numpy \
    mousepad \
    geany 

RUN apt-get install -y --no-install-recommends \
    mesa-utils \
    mesa-utils-extra \
    glmark2 

### noVNC needs python2 and ubuntu docker image is not providing any default python
RUN test -e /usr/bin/python && rm -f /usr/bin/python ; ln -s /usr/bin/python3 /usr/bin/python

RUN apt-get purge -y xscreensaver* && \
    apt-get -y clean

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN mkdir -p $NO_VNC_HOME/utils/websockify && \
    wget -qO- https://netcologne.dl.sourceforge.net/project/tigervnc/stable/1.10.1/tigervnc-1.10.1.x86_64.tar.gz | tar xz --strip 1 -C / && \
    wget -qO- https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME && \
    wget -qO- https://github.com/novnc/websockify/archive/v0.10.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME/utils/websockify && \
    chmod +x -v $NO_VNC_HOME/utils/*.sh && \  
    cp -f $NO_VNC_HOME/vnc.html $NO_VNC_HOME/index.html

# firefox
RUN add-apt-repository ppa:mozillateam/ppa && apt update && apt install -y firefox-esr

# paraview
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends mpich  qtbase5-dev qt5-qmake && \
    apt-get clean && rm -fr /var/lib/apt/lists/* 

RUN cd /usr/local; wget -c 'https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v5.11&type=binary&os=Linux&downloadFile=ParaView-5.11.1-MPI-Linux-Python3.9-x86_64.tar.gz' -O - | tar -xz 

# salome
RUN apt update && apt install -y curl
COPY SALOME-$SALOME_VERSION.tar.gz /opt/SALOME-$SALOME_VERSION.tar.gz
RUN tar -C /opt -xf /opt/SALOME-$SALOME_VERSION.tar.gz --totals && rm /opt/SALOME-$SALOME_VERSION.tar.gz && chown -R ${NB_USER} /opt/SALOME-9.11.0-native-UB22.04-SRC && ln -s /opt/SALOME-9.11.0-native-UB22.04-SRC /opt/SALOME-$SALOME_VERSION

# Dependencies obtained by running (in the SALOME directory) /opt/SALOME-9.11.0/sat/sat config SALOME-9.11.0 --check_system
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    dbus python3-babel python3-pytest-cython python3-jinja2 python3-pil python3-pyqt5 python3-pygments python3-sphinx python3-alabaster python3-certifi python3-chardet python3-click libcminpack1 python3-cycler python3-dateutil python3-docutils libfreeimage3 graphviz python3-idna python3-imagesize python3-kiwisolver clang python3-markupsafe python3-matplotlib libmetis5 python3-mpi4py python3-nose python3-numpydoc python3-pandas python3-psutil python3-tz libqwt-qt5-6 python3-requests libdc1394-25 libopenexr25 gfortran-11 libilmbase25 libevent-2.1-7 libffi7 openmpi-bin libgdal30 libopenblas0-serial libtbb12 python3-scipy python3-sip python3-stemmer python3-sphinx-rtd-theme python3-sphinxcontrib.websupport sphinx-intl python3-statsmodels libtcl libtk libunwind8 libqt5x11extras5 libboost-all-dev

#python3 xterm dbus libbsd0 libbz2-1.0 libc6 libdrm2 libegl1 libexif12 libexpat1 libfftw3-double3 libfontconfig1 libgl1 libglu1-mesa libgomp1 libgphoto2-6 libice6 libjbig0 libltdl7 liblzma5 libncurses5 libnuma1 libpcre3 libquadmath0 libraw1394-11 libsm6 libstdc++6 libtiff5 libudev1 libusb-1.0-0 libuuid1 libx11-6 libx11-xcb1 libxau6 libxcb1 libxcb-glx0 libxcb-xfixes0 libxcb-xkb1 libxdmcp6 libxext6 libxft2 libxi6 libxkbcommon0 libxkbcommon-x11-0 libxmu6 libxpm4 libxrender1 libxss1 libxt6 zlib1g libsqlite3-0 \
#python3-babel python3-pytest-cython python3-jinja2 python3-pil python3-pyqt5 python3-pygments python3-sphinx python3-alabaster python3-certifi python3-chardet python3-click libcminpack1 python3-cycler python3-dateutil python3-docutils fftw libfreeimage3 graphviz python3-idna python3-imagesize python3-kiwisolver clang python3-markupsafe python3-matplotlib libmetis5 python3-mpi4py python3-nose python3-numpydoc python3-pandas python3-psutil python3-tz libqwt-qt5-6 python3-requests libdc1394-25 libopenexr25 gfortran-11 libilmbase25 libevent-2.1-7 libffi7 openmpi-bin libgdal30 libopenblas0-serial libtbb12 python3-scipy python3-sip python3-stemmer python3-sphinx-rtd-theme python3-sphinxcontrib.websupport sphinx-intl python3-statsmodels libtcl libtk libunwind8 libqt5x11extras5

RUN dbus-uuidgen > /etc/machine-id \
    && mkdir -p /var/run/dbus \
    && dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address \
    && chmod 755 /opt/SALOME-$SALOME_VERSION/env_launch.sh /opt/SALOME-$SALOME_VERSION/salome /opt/SALOME-$SALOME_VERSION/mesa_salome \
    && ln -s /opt/SALOME-$SALOME_VERSION/salome /usr/bin/salome \
    && ln -s /opt/SALOME-$SALOME_VERSION/mesa_salome /usr/bin/mesa_salome

### inject files
ADD ./src/xfce/ $HOME/
ADD ./src/scripts $STARTUPDIR

ADD ./src/etc /

### configure startup and set perms
RUN \
    /bin/sed -i '1 a. /headless/.bashrc' /etc/xdg/xfce4/xinitrc && \
    find $STARTUPDIR $HOME -name '*.sh' -exec chmod a+x {} + && \
    find $STARTUPDIR $HOME -name '*.desktop' -exec chmod a+x {} + && \
    chgrp -R 0 $STARTUPDIR $HOME && \
    chmod -R a+rw $STARTUPDIR $HOME && \
    find $STARTUPDIR $HOME -type d -exec chmod a+x {} + && \
    echo LANG=en_US.UTF-8 > /etc/default/locale && \
    locale-gen en_US.UTF-8

USER ${NB_UID}
WORKDIR ${HOME}
ENTRYPOINT ["/dockerstartup/desktop_startup.sh"]
CMD ["--wait"]





