""" 
this prepares an ffmpeg command to extract various perspectives from 360deg video
""" 

import argparse

parser = argparse.ArgumentParser(description="Extract frames from a video")

parser.add_argument("input", type=str, help="input video")
parser.add_argument("outdir", type=str, help="output directory")
parser.add_argument("--res", type=int, default=1280, help="resolution")
parser.add_argument("--rate", type=float, default=0.4, help="frame rate")
parser.add_argument("--fov", type=int, default=90, help="field of view")
parser.add_argument("--cam_man", type=int, default=95, help="degree at which the camera man is")
parser.add_argument("--pitch", type=int, default=0, help="pitch")

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

perspectives = []

def get_num_and_step(
    turnrate, 
    cam_man_segment, 
    ): 

    view_start = args.cam_man + cam_man_segment / 2
    view_segment = 360 - cam_man_segment

    yaw_segment = view_segment - args.fov
    yaw_start = view_start + args.fov / 2 

    num = round(yaw_segment / turnrate) 
    deg_step = yaw_segment / (num - 1)
    return num, deg_step, yaw_start

class Circle: 
    def __init__(self, pitch, turnrate, cam_man_segment): 
        self.pitch = pitch
        self.turnrate = turnrate
        self.cam_man_segment = cam_man_segment

circles = [
    Circle(0, args.fov * 0.5, 90),
    Circle(35, args.fov * 0.8, 60),
    Circle(-35, args.fov * 0.8, 160), # nach unten 
    Circle(70, args.fov * 1.1, 60),
]

for circle in circles:
    num, deg_step, yaw_start = get_num_and_step(circle.turnrate, circle.cam_man_segment)
    for iyaw in range(num):
        perspectives.append(Perspective(circle.pitch, yaw_start + iyaw * deg_step, 0))

command = "mkdir -p " + args.outdir + " \n"
command += f'ffmpeg -i "{args.input}" -filter_complex '

filter_complex = "\"\n"
outputs = ""

for i, perspective in enumerate(perspectives): 
    perspective.clamp_yaw()
    filter_complex += f"[0:v]v360=input=equirect:output=rectilinear:h_fov={args.fov}:v_fov={args.fov}:pitch={perspective.pitch}:yaw={perspective.yaw}:roll={perspective.roll}:w={args.res}:h={args.res}[v{i}];\n"
    # make folder

    outputs += f"-map \"[v{i}]\" -r {args.rate} \"{args.outdir}/%05d_{i:03d}_{perspective.filename()}.jpg\" \\\n"

filter_complex += "\" \\\n"

command += filter_complex + outputs

print(command)
