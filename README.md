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

https://www.cnblogs.com/zhming26/p/6164131.html

https://github.com/DFabric/apps-static/blob/master/source/php-static/build.sh

https://web.mit.edu/kerberos/krb5-devel/doc/build/options2configure.html
https://github.com/krb5/krb5

https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=439039
https://stackoverflow.com/questions/15906203/compile-libgssapi-krb5-a-static-library-for-centos-6

https://blog.flxxyz.com/technology/2018/php-configure-error.html

# centos
https://rpmfind.net/linux/rpm2html/search.php?query=&submit=Search+...&system=&arch=
https://stackoverflow.com/questions/32102613/how-to-compile-a-program-with-static-libcurl
https://github.com/desktop/dugite-native/pull/102
https://www.cnblogs.com/clblacksmith/articles/8566922.html
http://www.code-by.org/viewtopic.php?t=188
https://www.zhihu.com/question/22940048
https://blog.csdn.net/wangzhen209/article/details/47153239
https://www.vpser.net/manage/centos-6-upgrade-gcc.html
https://jpanj.com/2018/centos-install-epel-repo/
https://pkgs.org/
https://edmondscommerce.github.io/installing-libsodium-and-pecl-libsodium-on-centos7-and-php7/
https://rpmfind.net/linux/rpm2html/search.php