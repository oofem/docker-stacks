# Choose your desired base image
FROM ubuntu:focal

ENV PYTHONPATH=/home/jovyan/oofem
ENV LD_LIBRARY_PATH=/home/jovyan/oofem

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

ENV DEBIAN_FRONTEND noninteractive
# Install some packages (libx11 xvfb and libgl1 needed by pyvista)
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends tini python3 python3-dev python3-pip libx11-6  libgl1-mesa-glx xvfb nano && \
    apt-get clean && rm -fr /var/lib/apt/lists/*

ENV PATH="/home/${NB_USER}/oofem:${PATH}" \
    HOME="/home/${NB_USER}"

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    chmod g+w /etc/passwd 

RUN pip install --upgrade pip && \
    pip install pyvista numpy matplotlib

RUN pip install jupyter 

USER ${NB_UID}

RUN mkdir "${HOME}/work" && \
    mkdir "${HOME}/notebooks" && \
    mkdir "${HOME}/notebooks/work" && \
    mkdir "${HOME}/notebooks/demos" && \
    mkdir "/home/${NB_USER}/oofem" && \
    mkdir "/home/${NB_USER}/oofem/examples" && \     
    chmod g+rwX "${HOME}/work" "${HOME}/notebooks" "${HOME}/notebooks/work"
    

COPY build/* ${HOME}/oofem/
COPY config/jupyter_notebook_config.py /etc/jupyter
COPY examples/Welcome.ipynb ${HOME}/notebooks
COPY examples/vtkdemo.ipynb ${HOME}/notebooks/demos
COPY examples/running_solver_demo.ipynb ${HOME}/notebooks/demos
COPY examples/c.in ${HOME}/oofem/examples
COPY examples/patch100.in ${HOME}/oofem/examples
COPY examples/util.py ${HOME}/notebooks/demos
COPY examples/Generating_model.ipynb ${HOME}/notebooks/demos

WORKDIR ${HOME}/notebooks
RUN jupyter notebook --generate-config


USER root

EXPOSE 8888

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["jupyter", "notebook", "/home/jovyan/notebooks/Welcome.ipynb", "--ip=\"0.0.0.0\""]

USER ${NB_UID}
WORKDIR ${HOME}/oofem
