## 导出执行文件
```bash
docker run --rm -v /home/auooru/php:/outd --entrypoint="" php-bin:latest /bin/cp -rf . /outd
```

## 资料

https://stackoverflow.com/questions/35879203/linux-php-7-configure-error-please-reinstall-readline-i-cannot-find-readline  
https://stackoverflow.com/questions/35891777/linux-correct-flag-to-pass-gcc-mcrypt-h-location  
https://packages.debian.org/search?keywords=readline&searchon=names&suite=buster&section=all  
https://jcutrer.com/linux/how-to-compile-php7-on-ubuntu-14-04  

https://521-wf.com/archives/227.html  
http://blog.gaoyuan.xyz/2014/04/09/statically-compile-php/  
http://abcdxyzk.github.io/blog/2013/10/31/compiler-binutil-static/  
https://www.php.net/manual/zh/install.pecl.static.php  
https://github.com/docker-library/php/blob/master/7.2/buster/cli/Dockerfile  
https://github.com/docker-library/php/tree/master/7.2/buster/apache  
https://github.com/docker-library/php  

https://github.com/DFabric/apps-static/blob/master/source/php-static/build.sh
