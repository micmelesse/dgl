alias nv_drun='sudo docker run -it --network=host --runtime=nvidia --ipc=host -v $HOME/dockerx:/dockerx -w /dockerx/dgl'
nv_drun dgl-gpu-nvidia
