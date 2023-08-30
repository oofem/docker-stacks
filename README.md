# OOFEM Docker Stacks

OOFEM Docker Stacks are a set of ready-to-run Docker images containing OOFEM solver and related tools. The provided Dockerfile uses multistage-build pattern.

## Supported images
-  build: building image used to compile oofem. This is not production image
-  oofem: oofem image containing solver compiled in Release mode with examples
-  oofem-python: image bundling python3 and oofem with python bindings and several useful python modules
-  oofem-jupyter: image with jupyter notebook server, python and oofem
-  oofem-course: image based on oofem-python bundled with headless xfce+vnc+noVNC+mesa+paraview+salome

## To build individual images:
```
sudo docker build --target build -t build .
sudo docker build --target oofem -t oofem .
sudo docker build --target oofem-python -t oofem-python .
sudo docker build --target oofem-jupyter -t oofem-jupyter .
sudo docker build --target oofem-course -t oofem-course .

```

## Running the images
To run production images oofem, oofem-python use
```
sudo docker run -it image bash
```

To run oofem-jupyter (with jupyter notebook server) use
```
sudo docker run -p 8888 -it oofem-jupyter
```

To launch oofem-course use
```
sudo docker run --rm -p "5901:5901" -p "6901:6901" --name quick --hostname quick oofem-course
````
then either use vnc(remote desktor viever) client to connect (use vncpasswd as password) or point your browser to http://localhost:6901/?password=vncpassword

