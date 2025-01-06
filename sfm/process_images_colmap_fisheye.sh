image_folder=$1
project_folder=$2

# check that both arguments are provided
if [ -z "$image_folder" ] || [ -z "$project_folder" ]; then
    echo "Usage: $0 <image_folder> <project_folder>"
    exit 1
fi

# prompt if folder exists
if [ -d "$project_folder" ]; then
    echo "Folder already exists: $project_folder"
    exit 1
fi
mkdir -p $project_folder



echo 'extracting features'
time colmap feature_extractor \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --ImageReader.camera_model "OPENCV_FISHEYE" \
    --ImageReader.camera_params "1157.8588384589177,1157.8588384589177,-8.1170785103505594,0.59274162207590098,0.11402237187477461,-0.014600308783971828,-0.0020903417659602999,0.0052021808737947022" \
    2>&1 | tee $project_folder/feature_extractor.log 

echo 'matching features'
time colmap sequential_matcher \
    --database_path $project_folder/database.db \
    --SequentialMatching.overlap 20 \
    2>&1 | tee $project_folder/exhaustive_matcher.log 

mkdir -p $project_folder/sparse
echo 'mapping'
time colmap mapper \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --output_path $project_folder/sparse \
    2>&1 | tee $project_folder/mapper.log 

echo "choosing largest sparse folder"
sparse_folder=""
max=0
for f in $project_folder/sparse/*; do
	size=$(du -k "$f" | cut -f1)
    if [ "$size" -gt "$max" ]; then
        max=$size
        sparse_folder="$f"
    fi
done

if [ -z "$sparse_folder" ]; then
    echo "no sparse folder found"
else
	echo 'running bundle adjustment'
	time colmap bundle_adjuster \
		--input_path $sparse_folder \
		--output_path $project_folder/bundle_adjusted \
		--BundleAdjustment.refine_focal_length 1 \
		--BundleAdjustment.refine_principal_point 1 \
		--BundleAdjustment.refine_extra_params 1 \
		2>&1 | tee $project_folder/bundle_adjuster.log 

	colmap point_filtering \
		--input_path $project_folder/bundle_adjusted \
		--output_path $project_folder/filtered \
		--min_track_len 3 \
		--max_reproj_error 3.0 \
		--min_tri_angle 2.0 \
		2>&1 | tee $project_folder/point_filtering.log 

	echo 'undistorting'
	time colmap image_undistorter \
		--image_path $image_folder \
		--input_path $project_folder/filtered \
		--output_path $project_folder/undistorted \
		--output_type COLMAP \
		2>&1 | tee $project_folder/image_undistorter.log 
fi
