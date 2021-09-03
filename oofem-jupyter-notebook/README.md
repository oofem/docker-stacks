# oofem-jupyter-notebook

oofem-jupyter-notebook image, which provides ready-to-use oofem installation with generated python bindings and Jupyter notebook server.

- Precompiled oofem (development version from main branch) with generated python bindings
- Python3.X with pyvista numpy and matplotlib modules installed
- Jupyter notebook server


## Usage scenarios
   - running the container with the default entry point will start juyter notebook server. Use -p option to publish jupyter notebook server port 8888 to the host 
   ```
   docker run -p 8888 -it oofem-jupyter-notebook
   ````
   - run container with shell as entry point. This allows to use precompiled oofem executable and also use python interface.
   ```
   docker run -it oofem-hupyter-notebook bash
   
   ```
