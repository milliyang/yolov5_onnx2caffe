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
	cd $NNIE_DIR/yolov5
	echo "current dir: $(pwd)"

	# export yolo5 to onnx model
	#
	# cd yolov5
	# conda activate nnie311
	# /home/leo/anaconda3/envs/nnie311/bin/python export.py --data coco.yaml --weights best.pt --batch 1 --img 640 640 --simplify --include onnx --opset 10
	cd $NNIE_DIR/yolov5
	MYPYTHON=/home/leo/anaconda3/envs/nnie311/bin/python
	#$MYPYTHON export.py --data coco.yaml --weights best.pt --batch 1 --img 640 640 --simplify --include onnx --opset 12
	$MYPYTHON export.py --data coco.yaml --weights best.pt --batch 1 --img 416 416 --include onnx --opset 12
	code=$?
	#check OK
	if [ $code -ne 0 ]; then
		echo "export yolo5 to onnx model failed"
		exit 1
	fi

	$MYPYTHON -m onnxsim best.onnx best-sim.onnx

    echo " input: best.pt"
	echo "output: best.onnx best-sim.onnx"
	md5sum *.onnx *.pt
	ls -alh *.onnx *.pt
}

function convert_onnx_to_caffe() {
	cd $NNIE_DIR
	echo "current dir: $(pwd)"
	#convert onnx to caffe model
	#docker run -it --rm \
	#	-v $(pwd):/workspace \
	#	-w /workspace \
	#	leo_caffe:latest \
	#	/bin/bash -c 'export PYTHONPATH=/workspace/yolov5_caffe/python:$PYTHONPATH; cd /workspace/yolov5_onnx2caffe/ && python convertCaffe.py'

	docker run -it --rm \
		-v $(pwd):/workspace \
		-w /workspace \
		leo_caffe:latest \
		/bin/bash -c 'export PYTHONPATH=/workspace/yolov5_caffe/build/install/python:$PYTHONPATH; cd /workspace/yolov5_onnx2caffe/ && python convertCaffe.py'

}

function convert_caffe_to_wk() {
	cd $NNIE_DIR
	echo "current dir: $(pwd)"

	docker run -it --rm \
		-v $(pwd):/workspace \
		-w /workspace \
		nnie_mapper:ubuntu1404 \
		/bin/bash -c 'export PATH=/workspace/1404/opencvlib/bin:$PATH; \
		export LD_LIBRARY_PATH=/workspace/1404/opencvlib/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH; \
		export PKG_CONFIG_PATH=/workspace/1404/opencvlib/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH; \
		cd /workspace/nnie_mapper; \
		../1404/nnie_mapper_11 yolov5_yuv.cfg; \
		scp *.wk thyang@192.168.9.102:/lhome3/thyang/nfs_4e6e437f58/'
}

export_yolo5_onnx
convert_onnx_to_caffe
convert_caffe_to_wk

cd $LAST_DIR