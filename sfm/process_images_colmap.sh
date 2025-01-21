image_folder=$1
project_folder=$2

flf=0.5
sequential_overlap=12

# prompt if folder exists
if [ -d "$project_folder" ]; then
    echo "Folder already exists: $project_folder"
    read -p "Do you want to remove it? (y/n): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        rm -rf "$project_folder"
        echo "Removed folder: $project_folder"
    else
        echo "Exiting script."
        exit 1
    fi
fi

mkdir -p $project_folder

echo 'extracting features'
time colmap feature_extractor \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --ImageReader.single_camera_per_folder 1 \
	--ImageReader.default_focal_length_factor $flf \ 
    2>&1 | tee $project_folder/feature_extractor.log

echo 'matching features'
time colmap sequential_matcher \
    --database_path $project_folder/database.db \
    --SequentialMatching.overlap $sequential_overlap \
    2>&1 | tee $project_folder/exhaustive_matcher.log

mkdir -p $project_folder/sparse
echo 'mapping'
time colmap mapper \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --output_path $project_folder/sparse \
    2>&1 | tee $project_folder/mapping.log

echo "choosing largest sparse folder"
sparse_folder=""
max=0
for f in $project_folder/sparse/*; do
	size=$(du -k "$f" | cut -f1)
	echo "$f: $size"
    if [ "$size" -gt "$max" ]; then
        max=$size
        sparse_folder="$f"
    fi
done
echo "choosing $sparse_folder"

if [ -z "$sparse_folder" ]; then
    echo "no sparse folder found"
else
	echo 'bundle adjustment'
	bundle_adjusted_dir="$project_folder/bundle_adjusted"
	mkdir -p "$bundle_adjusted_dir"
	time colmap bundle_adjuster \
		--input_path $sparse_folder \
		--output_path $bundle_adjusted_dir \
		2>&1 | tee $project_folder/bundle_adjuster.log 
#	# paused args
#		--BundleAdjustment.refine_focal_length 1 \
#		--BundleAdjustment.refine_principal_point 1 \
#		--BundleAdjustment.refine_extra_params 1 \

	echo 'filtering'
	filtered_dir="$project_folder/filtered"
    mkdir -p "$filtered_dir"
	colmap point_filtering \
		--input_path $bundle_adjusted_dir \
		--output_path $filtered_dir \
		--min_track_len 3 \
		--max_reproj_error 3.0 \
		--min_tri_angle 2.0 \
		2>&1 | tee $project_folder/point_filtering.log 

	# estimate orientation
	echo 'estimating orientation'
	oriented_dir="$project_folder/oriented"
	mkdir -p "$oriented_dir"
	time colmap model_orientation_aligner \
		--image_path $image_folder \
		--input_path $filtered_dir \
		--output_path $oriented_dir \
		2>&1 | tee $project_folder/orientation.log

	echo 'undistorting'
	undistorted_dir="$project_folder/undistorted"
	time colmap image_undistorter \
		--image_path $image_folder \
		--input_path $oriented_dir \
		--output_path $undistorted_dir \
		--output_type COLMAP \
		2>&1 | tee $project_folder/image_undistorter.log 
fi

