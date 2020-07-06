build_container:
	cd lsws-magento-dockerfiles/template; \
	./build.sh --lsws 5.4.7 --php lsphp74
	
say_hello:
	echo "Hello World"

prune:
	docker-compose kill
	sudo rm -rf data
	sudo rm -rf sites/localhost/html/*

reinstall:
	docker-compose kill
	docker-compose rm -f
	sudo rm -rf data
	sudo rm -rf sites/localhost/html/*
	sudo rm -rf lsws/*
	docker-compose up -d
	sleep 6
	./bin/database.sh -D localhost
	./bin/appinstall.sh -A magento -D localhost
	
reinstall_sample:
	docker-compose kill
	docker-compose rm -f
	sudo rm -rf data
	sudo rm -rf sites/localhost/html/*
	sudo rm -rf lsws/*
	docker-compose up -d
	sleep 6
	./bin/database.sh -D localhost
	./bin/appinstall.sh -A magento -S -D localhost
