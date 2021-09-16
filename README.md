# OOFEM Docker Stacks

OOFEM Docker Stacks are a set of ready-to-run Docker images containing OOFEM solver and related tools. The provided Dockerfile uses multistage-build pattern.

##Supported images
-  build: building image used to compile oofem. This is not production image
-  oofem: oofem image containing solver compiled in Release mode with examples
-  oofem-python: image bundling python3 and oofem with python bindings and several useful python modules
-  oofem-jupyter: image with jupyter notebook server, python and oofem

##The workflow to build individual images:
```
sudo docker build --target build -t build .
sudo docker build --target oofem -t oofem .
sudo docker build --target oofem-python -t oofem-python .
sudo docker build --target oofem-jupyter -t oofem-jupyter .
```

##Running the images
To run production images oofem, oofem-python use
```
sudo docker run -it image bash
```

To run oofem-jupyter (with jupyter notebook server) use
```
sudo docker run -p 8888 -it oofem-jupyter
```
