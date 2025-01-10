""" 
this prepares an ffmpeg command to extract various perspectives from > 180deg fisheye video
""" 

import argparse

parser = argparse.ArgumentParser(description="Extract frames from a video")

parser.add_argument("input", type=str, help="input video")
parser.add_argument("outdir", type=str, help="output directory")
parser.add_argument("--res", type=int, default=1280, help="resolution")
parser.add_argument("--rate", type=float, default=0.4, help="frame rate")
parser.add_argument("--ifov", type=int, default=180, help="field of view of the input")
parser.add_argument("--crop", type=int, default=10, help="crop in pixels before fisheye")
parser.add_argument("--fov", type=int, default=90, help="field of view of equirect output imgs")
parser.add_argument("--cam_man", type=int, default=90, help="degree at which the camera man is")
parser.add_argument("--pitch", type=int, default=0, help="pitch")
parser.add_argument("--just-one-frame", action="store_true")

args = parser.parse_args()

class Perspective: 
    def __init__(self, pitch, yaw, roll): 
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll

    def filename(self): 
        return f"p{self.pitch}_y{self.yaw}"

    def __str__(self): 
        return f"pitch: {self.pitch}, yaw: {self.yaw}"

    def clamp_yaw(self): 
        if self.yaw > 180: 
            self.yaw = -180 + (self.yaw - 180)

lookaround = 45
perspectives = [
    Perspective(0, 0, 0),
    Perspective(lookaround, 0, 0),
    Perspective(-lookaround, 0, 0),
    Perspective(0, lookaround, 0),
    Perspective(0, -lookaround, 0),
]


command = "rm -r " + args.outdir + " \n"
command += "mkdir -p " + args.outdir + " \n"
command += f'ffmpeg '
if args.just_one_frame:
    command += '-t 0.1 '
command += f'-i "{args.input}" -filter_complex '

filter_complex = "\"\n"
outputs = ""

for i, perspective in enumerate(perspectives): 
    perspective.clamp_yaw()
    filter_complex += f"[0:v]v360=input=fisheye:ih_fov={args.ifov}:output=rectilinear:h_fov={args.fov}:v_fov={args.fov}:pitch={perspective.pitch}:yaw={perspective.yaw}:roll=0:w={args.res}:h={args.res}[v{i}];\n"
    # v360=input=equirect:output=rectilinear:h_fov={args.fov}:v_fov={args.fov}:pitch={perspective.pitch}:yaw={perspective.yaw}:roll={perspective.roll}:w={args.res}:h={args.res}
    # make folder

    outputs += f"-map \"[v{i}]\" -r {args.rate} \"{args.outdir}/%05d_{i:03d}_{perspective.filename()}.jpg\" \\\n"

filter_complex += "\" \\\n"


command += filter_complex 

command += outputs

print(command)
