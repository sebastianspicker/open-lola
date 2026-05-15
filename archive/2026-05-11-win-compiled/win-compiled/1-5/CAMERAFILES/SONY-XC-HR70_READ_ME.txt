SONY XC-HR70
============

The default exposure setting for Lola is 100.000000, but when using 
the Sony XC-HR70 camera this value causes some artifacts on the image
(black lines or superimposed ghost images).

As a workaround you have to manually set the "Exposure" value in the 
LolaGui.ini file (*) using the following indications:

- 640x480,  30 fps --> Exposure=31.000000
- 1024x768, 29 fps --> Exposure=30.000000


If you don't want to edit the file every time you change the camerafile,
you can set the following values which work for both:

- FrameRate=29.000000
- Exposure=30.000000 


------------------------------------------------------------------------
(*) The file is created by Lola during the first start/end cycle.


