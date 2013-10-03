BezierDrawing
=============

Love2D Drawing Library using cubic Bezier curves.

Stuff:
-------------
- Use Bezier curves to draw shapes
- At any time, click outside of the shape to render it
- Automatically renders Normalmaps and specmaps for the shape (in a background thread)
- Define your own materials using a simple API, which will control the normalmap, specmap and colors of your shapes (see "Materials" subfolder for examples).

Kudos:
-------------

These scripts work with the (awesome) Löve engine (love2d.org).
They will be part of a game I'm planning and are very specific to it. Still, if you can find another use for them, feel free to use them.

Thanks to [vrld](https://github.com/vrld), who's code I closely relied on for the camera and some math functions and who gave me some starter tips on Bezier curves.
Also thanks to [mattdesl](https://github.com/mattdesl) for the [awesome tutorial](https://github.com/mattdesl/lwjgl-basics/wiki/ShaderLesson6) on normalmapping for 2d games using OpenGL.


To Do:
-------------

- [Done] Copy Shape
- Box select
- [Canceled] Rotate selection
- [Canceled] Scale selection
- [Done] Move selection
- [Done] Fill shape
- [Done] Change color/Material
- [Done] Render normalmaps
