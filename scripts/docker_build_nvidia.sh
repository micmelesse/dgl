cd docker
# wget https://s3.us-east-2.amazonaws.com/dgl.ai/dataset/FB15k.zip -P install/
# docker build -t dgl-gpu -f Dockerfile.ci_gpu_torch_1.2.0 .

docker build -t dgl-gpu -f Dockerfile.ci_gpu .