# DDCropController
DDCropController is my take on a simple yet somewhat complicated task of providing users with a tool to crop the UIImage to a defined asepct ratio.

## Screenshots

|   |   |   |
|---|---|---|
| ![Image](<Screenshots/Screenshot-1.png>) | ![Image](<Screenshots/Screenshot-2.png>) | ![Image](<Screenshots/Screenshot-3.png>) |

## Usage
Create a controller, passing the image and the aspect ratio and prepare to listen for its delegate meethod on completion.

Controller supports all combinations of both original image and crop rect's aspect ratios, which, as I've found out the hard way, is not the case in most of the other existent solutions.

The 'Cancel' and 'Crop' button texts can be provided on controller's creation for the localization and customization purposes. Otherwise the fallback generic English strings will be used instead.

Controller was designed to be simplistic and lightweight, with no storyboards and XIBs, and with minimum excessive layouting.

## Usage in Projects
If you use the DDCropController in your published app and would like to be included in the usage list here – PM me the link! :-)

## Contibutions
Contributions are welcome!
