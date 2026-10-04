extends RefCounted
# Elliptic section meshes: cloth, anatomical silhouettes and tapered machine shells.
# Profile entries are (height, half width, half depth); no external texture dependencies.
static func loft(parent:Node3D,profile:Array,at:Vector3,mat:Material,folds:float=0.0,segments:int=16)->MeshInstance3D:
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for col in range(segments):
			for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(0,1),Vector2i(0,0),Vector2i(1,0),Vector2i(1,1)]:
				var section:Vector3=profile[row+corner.y]
				var angle:float=TAU*float(col+corner.x)/segments
				var wrinkle:float=1.0+folds*sin(angle*5.0+(row+corner.y)*1.7)
				var prev:Vector3=profile[maxi(0,row+corner.y-1)]
				var next:Vector3=profile[mini(profile.size()-1,row+corner.y+1)]
				var slope:float=((prev.y-next.y)+(prev.z-next.z))*0.5/maxf(next.x-prev.x,0.01)
				s.set_normal(Vector3(cos(angle),slope,sin(angle)).normalized())
				s.set_uv(Vector2(float(col+corner.x)/segments,float(row+corner.y)/(profile.size()-1)))
				s.add_vertex(Vector3(cos(angle)*section.y*wrinkle,section.x,sin(angle)*section.z*wrinkle))
	var mesh:=MeshInstance3D.new();mesh.mesh=s.commit();mesh.material_override=mat;parent.add_child(mesh);mesh.position=at;return mesh
static func ellipsoid(parent:Node3D,at:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
	var m:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=16;sphere.rings=8;m.mesh=sphere;m.material_override=mat;parent.add_child(m);m.position=at;m.scale=size;return m

