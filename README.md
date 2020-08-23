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

This is intended to be the OpenStreetmap for caves, where cave explorers can conveniently 
edit a 3D model of the caves they know about to build up an accurate map.

Note that laser point scan to 1mm accuracy is not a map, any more than a satellite photograph is a map.  
A map is a representation of the landscape that shows the details that are important for what it is used for.

The cave map is intended to be used for:
 (a) route finding and discovery,
 (b) illustrating what is there to someone who has not been there (same purpose as an expensive photograph),
 (c) showing where the ropes and rigging go because it's dimensionally accurate,
 (d) fun collaborative artwork (it's easier to collaborate on a representation of something real, than 
a landscape that is purely made up.

TunnelVR is multiplayer so that two or people can interact, either as a tourist and guide, 
a teacher and student of the editing tools, or collaborators on improving the representation of 
a particular area of the cave.


## Controls

The control binding is a challenge and is evolving.  Owing to a lack of artistic ability, 
the hands and head are made using CSG subtraction or union of a box and a sphere.

*Left hand* is for movement.
* Thumb touchpad -- slides forward or backward in direction of view
* Thumb touchpad click left or right -- rotates view 45 degrees left or right
* Grip -- turns off gravity
* Grip+Trigger -- Flies in direction of controller axis
* Grip+Touchpad+Trigger -- Flies in direction of controller at 3x speed.

*Right hand* is for drawing.
Note that there is a laser pointer coming out of the palm with a range of 50m.
* Trigger on floor or transparent XC pane -- draw a new node (which is selected)
* Trigger on unselected node -- selects node and draws or deletes a line if there is a previously selected node.  
If it is part of an unselected XC pane, then it selects the pane and the pointer will see through walls to reach it.
* Trigger on selected node -- deselects node
* Grip+Trigger on floor or XC pane -- Moves node
* Grip+Trigger on selected node -- Deletes node
* Grip+ungrip on selected XC pane -- deselects XC pane
* Grip+ungrip otherwise -- deselects selected node
* Trigger on tube -- Selects tube and sector of tube
* Thumb touch pad click left or right on selected tube -- advances the selected sector
* Thumb touch pad click up or down on selected tube -- advances the material within the selected sector

* Menu button (above touchpad) -- Open dialog window with further controls
The important options is the Update Tubes if the tubes aren't being built properly.  

*Gestures*
* Right controller held horizontal above and to right of forehead when click menu button -- toggle the headtorch light
* Left controller pointed towards palm so a dial appears, then left grip and rotate -- changes the angle of the laser.

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


![Screenshot](screenshot.png)
