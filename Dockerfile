# Multi stage build
# Images:
#  build: build image used to compile oofem (in release mode with python bindings)
#  oofem: plain oofem solver image
#  oofem-python: oofem + python interface+ python
#  oofem-jupyter: oofem + python interface + jupyter notebook server

ARG NB_USER="jovyan"
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
    make -j 8
    
# -------------------------------------------------------------------------
# Basic oofem distribution image
# -------------------------------------------------------------------------
FROM ubuntu AS oofem
ARG NB_USER
ARG NB_UID
ARG NB_GUD
COPY --from=build /tmp/oofem/build/oofem /bin
COPY --from=build /tmp/oofem/build/liboofem.so /lib
COPY --from=build /tmp/oofem/build/oofempy.so /lib
RUN useradd --user-group --system --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" "${NB_USER}"
ENV HOME="/home/${NB_USER}"
USER ${NB_USER}
RUN mkdir "${HOME}/oofem-examples"
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
    apt-get install --yes --no-install-recommends tini python3 python3-dev python3-pip libx11-6  libgl1-mesa-glx xvfb nano && \
    apt-get clean && rm -fr /var/lib/apt/lists/* && \
    pip install --upgrade pip && \
    pip install pyvista numpy matplotlib
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
RUN pip install jupyter 

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





