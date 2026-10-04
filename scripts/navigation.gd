extends RefCounted
# Shared grid navigation: every path segment is axis-aligned through free cells.
static func world(data:Dictionary,c:Vector2i)->Vector3:
	return Vector3((c.x-(data.width-1)*0.5)*data.cell,0,(c.y-(data.height-1)*0.5)*data.cell)
static func cell(data:Dictionary,p:Vector3)->Vector2i:
	return Vector2i(roundi(p.x/data.cell+(data.width-1)*0.5),roundi(p.z/data.cell+(data.height-1)*0.5))
static func is_walkable(data:Dictionary,c:Vector2i)->bool:
	return c.x>=0 and c.y>=0 and c.x<data.width and c.y<data.height and not data.blocked.has(c)
static func nearest(data:Dictionary,p:Vector3)->Vector2i:
	var c:=cell(data,p)
	c.x=clampi(c.x,0,data.width-1)
	c.y=clampi(c.y,0,data.height-1)
	if is_walkable(data,c):return c
	for radius in range(1,maxi(data.width,data.height)):
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				var candidate:=c+Vector2i(dx,dy)
				if absi(dx)+absi(dy)==radius and is_walkable(data,candidate):return candidate
	return Vector2i.ZERO
static func cells(data:Dictionary,from:Vector2i,to:Vector2i)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	if not is_walkable(data,from) or not is_walkable(data,to):return result
	var queue:Array[Vector2i]=[from]
	var came:Dictionary={from:from}
	var index:int=0
	while index<queue.size():
		var current:=queue[index]
		index+=1
		if current==to:
			var cursor:=to
			while cursor!=from:
				result.push_front(cursor)
				cursor=came[cursor]
			result.push_front(from)
			return result
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next:Vector2i=current+direction
			if is_walkable(data,next) and not came.has(next):
				came[next]=current
				queue.append(next)
	return result
static func path(data:Dictionary,from:Vector3,to:Vector3)->Array[Vector3]:
	var points:Array[Vector3]=[]
	for c in cells(data,nearest(data,from),nearest(data,to)):points.append(world(data,c))
	return points

static func reachable(data:Dictionary,from:Vector2i)->Dictionary:
	var visited:Dictionary={}
	if not is_walkable(data,from):return visited
	var queue:Array[Vector2i]=[from]
	visited[from]=true
	var i:int=0
	while i<queue.size():
		var c:=queue[i]
		i+=1
		for offset in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next:Vector2i=c+offset
			if is_walkable(data,next) and not visited.has(next):
				visited[next]=true
				queue.append(next)
	return visited

