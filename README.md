# OOFEM Docker Stacks

OOFEM Docker Stacks are a set of ready-to-run and ready-to-build Docker images containing OOFEM solver and related relevant tools.

The typical workflow
-  Built the oofem-build image and create a new container from this image
   ```
   cd oofem-build
   docker build --rm -t oofem-build -f Dockerfile .
   docker create --name oofem-buildctn oofem-build
   ```
- Copy oofem executable and libraries from build container
  ```
  cd oofem-jupyter-notebook
  mkdir build
  sudo docker cp oofem-buildimg:/tmp/oofem/build/oofem ./build
  sudo docker cp oofem-buildimg:/tmp/oofem/build/liboofem.so ./build
  sudo docker cp oofem-buildimg:/tmp/oofem/build/oofempy.so ./build
  ```
- Create a production container image
  ```
  sudo docker build --rm -t oofemcourse -f Dockerfile .
  #optionally save container into tgz file
  sudo  docker image save oofemcourse -o oofemcourse.di 
  ```
- Users can uploaded saved container into their docker environment using
  ```
  docker image load -i oofemcourse.di
  ```