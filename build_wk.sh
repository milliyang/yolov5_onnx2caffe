#! /bin/bash

CURRENT_FILE_DIR=$(dirname $(readlink -f $0))
NNIE_DIR=$(dirname $CURRENT_FILE_DIR)
LAST_DIR=$(pwd)

#check if the docker image is built
docker images | grep leo_caffe
if [ $? -ne 0 ]; then
	echo "leo_caffe image not found"
	exit 1
fi

#check yolov5
if [ ! -d $NNIE_DIR/yolov5 ]; then
	echo "yolov5 not found"
	exit 1
fi

#check yolov5_onnx2caffe
if [ ! -d $NNIE_DIR/yolov5_onnx2caffe ]; then
	echo "yolov5_onnx2caffe not found"
	exit 1
fi

echo "NNIE_DIR: $NNIE_DIR"
echo "CURRENT_FILE_DIR: $CURRENT_FILE_DIR"

function export_yolo5_onnx() {
	#go to nnie/
	cd $NNIE_DIR

	# export yolo5 to onnx model
	#
	# cd yolov5
	# conda activate nnie311
	# /home/leo/anaconda3/envs/nnie311/bin/python export.py --data coco.yaml --weights best.pt --batch 1 --img 640 640 --simplify --include onnx --opset 10
	cd $NNIE_DIR/yolov5
	MYPYTHON=/home/leo/anaconda3/envs/nnie311/bin/python
	$MYPYTHON export.py --data coco.yaml --weights best.pt --batch 1 --img 640 640 --simplify --include onnx --opset 10
	code=$?
	#check OK
	if [ $code -ne 0 ]; then
		echo "export yolo5 to onnx model failed"
		exit 1
	fi
}

function convert_onnx_to_caffe() {
	cd $NNIE_DIR
	echo "current dir: $(pwd)"
	#convert onnx to caffe model
	docker run -it --rm \
		-v $(pwd):/workspace \
		-w /workspace \
		leo_caffe:latest \
		/bin/bash -c 'export PYTHONPATH=/workspace/yolov5_caffe/python:$PYTHONPATH; cd /workspace/yolov5_onnx2caffe/ && python convertCaffe.py'

}

export_yolo5_onnx
convert_onnx_to_caffe

cd $LAST_DIR