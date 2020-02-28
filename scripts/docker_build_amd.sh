cd docker
wget https://s3.us-east-2.amazonaws.com/dgl.ai/dataset/FB15k.zip -P install/
docker build -t dgl-cpu -f Dockerfile.ci_cpu .