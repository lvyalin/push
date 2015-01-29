#!/bin/bash
#############################################################################
# 使用帮助
if [ $# -ne 1 ] || [ "-h" = "$1" ] || [ "--help" = "$1" ]
then
    echo "介绍: 发布代码到服务器"
    echo "用法: sh $0 PROJECT"
    echo "参数: PROJECT 该参数是项目的标示，对应配置文件里的conf/conf.PROJECT.sh"
    exit
fi
#############################################################################
#   配置项
#   include lib
DEPLOY_TOOLS_DIR=`dirname $this_file`
. $DEPLOY_TOOLS_DIR/common/utils.sh
. $DEPLOY_TOOLS_DIR/common/common.sh

# 获取配置文件
if [ ! -f "./conf/conf.${PROJECT}.sh" ]
then
    cecho "配置文件加载失败 请配置./conf/conf.${PROJECT}.sh"
    exit
fi
. ./conf/conf.${PROJECT}.sh
#############################################################################
# 确认上线服务器地址
cecho "\n=== 上线服务器列表 === \n" $c_notify
no=0;
for host in $ONLINE_HOSTS
do
    no=`echo "$no + 1" | bc`
    cecho "$no\t$host";
done
echo ""
deploy_confirm "确认服务器列表？"
if [ 1 != $? ]; then
    exit 1;
fi
#############################################################################
# 获取svn文件
CURRENT_REVISION=`svn --xml info $SVN_URL | grep 'revision' | head \-1 | awk -F '\"' '{ print \$2 }'`
PROJECT_TAG=${TAG_DIR}${PROJECT}.${CURRENT_REVISION}"/"
LAST_REVISION=`cat ${LOG_DIR}${PROJECT}.log`
LAST_PROJECT_TAG=${TAG_DIR}${PROJECT}.${LAST_REVISION}"/"
svn export --force -r$CURRENT_REVISION $SVN_URL $PROJECT_TAG > /dev/null
#############################################################################
# 提示变更内容tag
#############################################################################
# 提示变更文件对比
dir_diff=`diff -rbB --brief $PROJECT_TAG $LAST_PROJECT_TAG | grep -v "\.svn" | awk '{ if("Files"==$1) { print "!\t"$2; }; if("Only"==$1) { print "+\t"substr($3,1,length($3)-1)"/"$4 } }'`

while [ 1 = 1 ]
do
    if [ -z "$dir_diff" ]
    then
        cecho "没有找到不同的文件" $c_notify
        break
    fi
    
    echo -e "$dir_diff"
	cread -p "输入比较文件的路径（路径参考以上输出），n退出；左帧SVN: " file $c_notify

    if [ "n" = "$file" ]; then
        break;
    fi

    if [ "" = "$file" ]; then
        continue;
    fi

    local_file="$file"
    online_file="${TAG}/$file"

    if [ ! -s "$local_file" ]; then
        cecho "没有找到文件，确认文件路径是否正确：$file" $c_error
        continue;
    fi
    echo -e "退出vimdiff ：qa"
    vimdiff $local_file $online_file
done

#############################################################################
# 源文件打包
cecho "\n=== 上线文件打包 === \n" $c_notify
cd ${PROJECT_TAG}
rm -f $DEPLOY_TOOLS_DIR${PROJECT}.zip
zip -r $DEPLOY_TOOLS_DIR${PROJECT}.zip ./ > /dev/null
cd -
#############################################################################
# 打包文件传输
cecho "\n=== 上线文件传输 === \n" $c_notify
for host in $ONLINE_HOSTS
do
    scp ${DEPLOY_TOOLS_DIR}${PROJECT}.zip $SSH_USER@$host:$PUBLIC_DIR
    cecho "传输到$host成功" $c_notify
    ssh $SSH_USER@$host "cd $PUBLIC_DIR;unzip ${DEPLOY_TOOLS_DIR}${PROJECT}.zip;"
    cecho "解压${PROJECT}.zip完成" $c_notify
done
#############################################################################
# 建立软连，执行命令
deploy_confirm "确认变更上线？"
if [ 1 != $? ]; then
    exit 1;
fi
for host in $ONLINE_HOSTS
do
    ssh $SSH_USER@$host "cd $PUBLIC_DIR;ln -T -s $PROJECT $HTDOCS_NAME;"
done
#############################################################################
# 发布成功写入记录
`echo "$CURRENT_REVISION" > ${LOG_DIR}${PROJECT}.log`