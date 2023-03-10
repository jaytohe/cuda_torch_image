FROM nvcr.io/nvidia/pytorch:22.08-py3

RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd

# Edit <password> to be the desired root password. Keep it a secret!
RUN echo 'root:1234' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise, the user is kicked off after login.
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

COPY ./nvidia_env_vars /etc/nvidia_env_vars
RUN cp /etc/bash.bashrc /etc/bash.bashrc.old
RUN cat <(echo "source /etc/nvidia_env_vars") /etc/bash.bashrc.old > /etc/bash.bashrc #Hack to allow Pytorch and CUDA to work over SSH.

RUN jupyter notebook --generate-config
RUN python <(echo 'from notebook.auth import passwd; print("c.NotebookApp.password=\"%s\"" % passwd("1234"))') > $HOME/.jupyter/jupyter_notebook_config.py
RUN echo 'c.NotebookApp.open_browser = False' >> $HOME/.jupyter/jupyter_notebook_config.py
RUN echo 'c.NotebookApp.port = 8888' >> $HOME/.jupyter/jupyter_notebook_config.py
RUN mkdir ~/Notebooks

#Compile modded Torch-Radon for current PyTorch version
RUN git clone https://github.com/faebstn96/torch-radon.git && cd torch-radon && python setup.py install

#Prepare Custom Subhadip's Conda Env
RUN git clone https://github.com/Subhadip-1/data_driven_convex_regularization.git /root/subhadip_ct_conda
RUN cd /root/subhadip_ct_conda && conda env create -f environment.yml

COPY init_sshd_jupyter /root/init_sshd_jupyter
RUN chmod +x /root/init_sshd_jupyter

EXPOSE 8888
EXPOSE 22
WORKDIR /root/Notebooks
CMD ["/usr/sbin/sshd", "-D"]

