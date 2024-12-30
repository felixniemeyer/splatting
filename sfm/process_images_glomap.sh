image_folder=$1
project_folder=$2

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
    > $project_folder/feature_extractor.log 2>&1

echo 'matching features'
time colmap sequential_matcher \
    --database_path $project_folder/database.db \
	--SequentialMatching.overlap 20 \
    > $project_folder/exhaustive_matcher.log 2>&1

mkdir -p $project_folder/sparse
echo 'glomap matching & mapping'
time glomap mapper \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --output_path $project_folder/sparse \
    > $project_folder/glomap.log 2>&1

echo 'undistorting'
time colmap image_undistorter \
    --image_path $image_folder \
    --input_path $project_folder/sparse/0 \
    --output_path $project_folder/undistorted \
    --output_type COLMAP \
    > $project_folder/image_undistorter.log 2>&1

