
user_script = """
base_cube = cq.Workplane('XY').rect(1.0,1.0).extrude(1.0)
top_of_cube_plane = base_cube.faces(">Z").workplane()
debug(top_of_cube_plane, { 'color': 'yellow', } )
debug(top_of_cube_plane.center, { 'color' : 'blue' } )

circle=top_of_cube_plane.circle(0.5)
debug(circle, { 'color': 'red' } )

show_object( circle.extrude(1.0) )
"""

user_script = """
result = cq.Workplane("front").box(2.0, 2.0, 0.5); show_object(result)
"""

# must fix the time.clock() call in the cqgi https://github.com/jmwright/cadquery-freecad-module/issues/147
from cadquery import cqgi, exporters
import io

parsed_script = cqgi.parse(user_script)
build_result = parsed_script.build(build_parameters={}, build_options={} )
if build_result.results:
    b = build_result.results[0]
    s = io.StringIO()
    exporters.exportShape(b.shape, "STL", s, 0.01)
    res = s.getvalue()
else:
    res = str(build_result.exception)
print(res)

