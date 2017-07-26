Lenovo Platform Deployer (LPD) is a bare metal configuration and orchestration utility. It automates the following processes:

- Lenovo IMM configuration
- using xCAT to deploy host OS
- configuring host OS
- perform additional application installation and configuration

System Requirements:
- 12 Lenovo 3550 servers
- 1 Lenovo 1G TOR switch (e.g. Lenovo RackSwitch G7052 - configured separately) and 2 Lenovo 10G TOR switches (e.g. Lenovo NE1032 RackSwitch - configured separately)
- this git repository
- Redhat Enterprise Server 7.3 and Atomic Host isos

The use case for this repository is to support Redhat Openshift platform on Lenovo 3550 servers. The defined setup consists
of 12 servers:

- 6 application nodes
- 2 infrastructure nodes
- 3 master nodes

For more details, please refer to the OpenShift Reference Architecture documentation.

To use this utility, first install a Redhat 7 server on the 12th node as the bastion node. Then follow the steps below to build
the docker container.

1. download the git repository and cd into lpd-openshift directory.

2. with the Dockerfile in the current directory, build the docker container. For example,

	```
	docker build -t <target docker image name> .
	```

	This will build a local docker image.

3. Run a docker container with the image. For example,

	```
	docker run -dit --stop-signal=RTMIN+3 -v /shared:/shared  --net=host --privileged -e "container=docker" --cap-add SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup --security-opt seccomp:unconfined --name=<a container name> <built target docker image> bash
	```

	This will run the LPD container in the background.

4. Configure the container. Run the following:

	```
	docker exec -it <container name> bash
	service xcatd start
	copycds <Redhat Atomic Host iso>
	copycds <Redhat Enterprise 7.3 Server iso>
	lsdef -t osimage
	```

	This should show the OS images just installed and complete the configuration process.

5. Configure the Redhat kickstart files. Do the following.

	```
	cp /lci/rh/* /opt/xcat/share/xcat/install/rh
	cp /lci/scripts/* /opt/xcat/share/xcat/install/scripts
	```

6. Commit the changes and the LPD container is ready for use.

