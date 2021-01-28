## Introduction 

**TunnelVR** is a follow-on from [TunnelX](https://github.com/CaveSurveying/tunnelx) -- a long-running 
program for drawing up cave surveys.  It's based on the excellent 
[Godot Game Engine](https://godotengine.org/) that's used for designing 
Virtual Reality games on an almost plug and play basis.


## Install instructions

Download and run Godot.

Clone this repo

Download the assets

For the HTC Vive (which is the platform it is being developed on), 
simply hit run and it should put you there.  The Vive works with OpenVR.

For other platforms you may need to edit "Spatial.gd" to get the right initializer.  


## Objective

This should work like an OpenStreetmap for caves, where cave explorers can conveniently 
edit and share common 3D models of the caves direcly on the web with the least effort.

Note that laser point scan to 1mm accuracy is not a map, any more than a satellite photograph is a map.  
A map is a representation of the landscape that shows the details that are important for what it is used for.

The cave map is intended to be used for:
 (a) route finding and discovery,
 (b) illustrating what is there to someone who has not been there (same purpose as an expensive photograph),
 (c) showing where the ropes and rigging go because it's dimensionally accurate,
 (d) fun collaborative artwork (it's easier to collaborate on a representation of something real, than 
a landscape that is purely made up.

TunnelVR is multiplayer so that two or people can interact, either as a tourist and guide, 
a teacher and student of the editing tools, or collaborators improving the representation of 
a particular area of the cave.


## Controls

Controllers and hand tracking works.  Controller buttons animates the hands to the appropriate gesture: 
* thumb and forefinger pinch is same as trigger button, 
* thumb and middle finger pinch is grip button
* thumb and pinky and ring finger at same time is menu button

### *Left hand* is for movement.
* Thumb touchpad -- slides forward or backward in direction of view
* Thumb touchpad click left or right -- rotates view 45 degrees left or right
* Grip -- turns off gravity
* Grip+Trigger -- Flies in direction of controller axis
* Grip+Touchpad+Trigger -- Flies in direction of controller at 5x speed.

### *Right hand* is for drawing.
Cave walls are done by creating polygons in vertical (sometimes horizontal) XC panes and then joining nodes between these polygons to create tubes that are divided into sectors.
There is a laser pointer coming out of the palm with a range of 50m.
* Trigger on unselected node -- selects node and draws or deletes a line if there is a previously selected node.  
If it is part of an unselected XC pane, then it selects the pane and the pointer will see through walls to reach it.
* Trigger on selected node -- deselects node
* Trigger on XC pane with node selected -- continues drawing a sequence
* Grip+Trigger on XC pane -- Moves selected node
* Grip+Trigger on selected node -- Deletes node
* Grip+ungrip on selected XC pane -- deselects XC pane
* Grip+ungrip otherwise -- deselects selected node
* Trigger on an active tube, then release on disk then click a point on the disk -- Creates an intermediate node which distorts the wall of the tube
* Grip on target+select menu option+release -- executes a context sensitive command or changes material
* Menu button (above touchpad) -- Open dialog window with further controls

### Grip menu options
* SelectXC
* HideXC
* DeleteXC
* DeleteTube

### Gestures
* Right hand twisted to the right and moved rapidly towards face -- shorten laser pointer to enter rope drawing mode
* Right hand twisted to the right and moved rapidly away from face -- return to normal pointer mode

## Geometric principle

The cave is made from a series of cross sections.  Most cross sections have a single contour, 
but junctions can have two lines cutting the outer contour to separate it into three internal areas.
Connections between nodes in one cross section to nodes in another cross section defines a tube.
The tube goes between the internal area that spans the connections or the outer area if none do.
Multiple connections divide the tube into sectors that can be assigned with different materials.
Tubes should never self-intersect (where the planes of cross sections cut through the contour) or 
intersect with other tubes.  It is always possible to change the cross-sections or insert new ones 
to handle a difficult junction area.  In the extreme case, the cave could be modelled as a sliced 
CAT scan with 1mm thick layers all perpendicular to the X-axis.  However, capability to 
change the orientation of the slices makes the modelling more symetrical.

## Input data
Cave data is sourced from [Cave-Registry](http://cave-registry.org.uk/) [NorthernEngland](http://cave-registry.org.uk/svn/NorthernEngland/)
First execute:
* "C:\Program Files (x86)\Survex\aven.exe" Ireby\Ireby2\Ireby2.svx
to process the data into a .3d file Then process this file (after first editing the input and output file names)
* python surveyscans\convertdmptojson.py
Now edit the call to `xcdatalistfromcentreline` in the tunnelvr source code and enabled it to load the centreline and tubes on load.  
Save and use as normal

![Screenshot](screenshot.png)
