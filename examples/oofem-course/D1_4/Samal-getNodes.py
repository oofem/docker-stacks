import SMESH
from salome.smesh import smeshBuilder
smesh = smeshBuilder.New()

mesh_ref = salome.IDToObject("0:1:2:8")
mesh = smesh.Mesh(mesh_ref)
print( smesh.GetMeshInfo(mesh) )

for node in mesh.GetNodesId():
    x,y,z = mesh.GetNodeXYZ( node )
    print(node, x, y, z)
