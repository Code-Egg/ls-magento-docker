build_container:
	cd lsws-magento-dockerfiles/template; \
	./build.sh --lsws 5.4.6 --php lsphp73
	
say_hello:
	echo "Hello World"
