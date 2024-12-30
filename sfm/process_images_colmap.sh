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
    > $project_folder/exhaustive_matcher.log 2>&1

mkdir -p $project_folder/sparse
echo 'mapping'
time colmap mapper \
    --database_path $project_folder/database.db \
    --image_path $image_folder \
    --output_path $project_folder/sparse \
    > $project_folder/mapper.log 2>&1

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
	echo 'undistorting'
	time colmap image_undistorter \
		--image_path $image_folder \
		--input_path $sparse_folder \
		--output_path $project_folder/dense \
		--output_type COLMAP \
		> $project_folder/image_undistorter.log 2>&1
fi

