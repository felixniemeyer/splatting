image_folder=$1
project_folder=$2

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

# 90 degree => 0.5 focal length factor 
flf=0.5

mkdir -p $project_folder

echo 'extracting features'
time colmap feature_extractor \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --ImageReader.single_camera_per_folder 1 \
	--ImageReader.default_focal_length_factor $flf \ 
	2>&1 | tee $project_folder/feature_extractor.log 

echo 'matching features'
# time colmap sequential_matcher \
#     --database_path $project_folder/database.db \
# 	--SequentialMatching.overlap 20 \
#     > $project_folder/exhaustive_matcher.log 2>&1
time colmap vocab_tree_matcher \
    --database_path $project_folder/database.db \
    --VocabTreeMatching.vocab_tree_path vocab_tree_flickr100K_words32K.bin \
    2>&1 | tee $project_folder/vocab_tree_matcher.log

mkdir -p $project_folder/sparse
echo 'glomap matching & mapping'
time glomap mapper \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --output_path $project_folder/sparse \
    --ba_iteration_num 5 \
    --skip_pruning 0 \
    --GlobalPositioning.max_num_iterations 300 \
    --BundleAdjustment.max_num_iterations 500 \
	--Thresholds.max_epipolar_error_E=0.5 \
	--Thresholds.max_epipolar_error_F=1.5 \
	--Thresholds.max_epipolar_error_H=1.5 \
	--Thresholds.min_inlier_num=50 \
	--Thresholds.min_inlier_ratio=0.4 \
	--Thresholds.max_rotation_error=5 \
    > $project_folder/glomap.log 2>&1

# optimization
sparse_folder="$project_folder/sparse/0"

echo 'bundle adjustment'
bundle_adjusted_dir="$project_folder/bundle_adjusted"
mkdir -p "$bundle_adjusted_dir"
time colmap bundle_adjuster \
	--input_path $sparse_folder \
	--output_path $bundle_adjusted_dir \
	2>&1 | tee $project_folder/bundle_adjuster.log 
# paused args
#	--BundleAdjustment.refine_focal_length 1 \
#	--BundleAdjustment.refine_principal_point 1 \
#	--BundleAdjustment.refine_extra_params 1 \

image_filtered_dir=$bundle_adjusted_dir #skip
# 90 degree => 1.4142 / 2
# flr=0.7071
# flr_min=$(echo "$flr - 0.05" | bc)
# flr_max=$(echo "$flr + 0.05" | bc)
# image_filtered_dir="$project_folder/image_filtered"
# colmap image_filterer \
# 	--input_path $bundle_adjusted_dir \
#     --output_path $image_filtered_dir \
#     --min_focal_length_ratio $flr_min \
#     --max_focal_length_ratio $flr_max \

echo 'filtering'
filtered_dir="$project_folder/filtered"
mkdir -p "$filtered_dir"
time colmap point_filtering \
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
mkdir -p "$undistorted_dir"
time colmap image_undistorter \
	--image_path $image_folder \
	--input_path $oriented_dir \
	--output_path $undistorted_dir \
	--output_type COLMAP \
	2>&1 | tee $project_folder/image_undistorter.log 

