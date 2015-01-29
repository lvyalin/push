#!/bin/bash
#############################################################################
# 使用帮助
if [ $# -ne 2 ] || [ "-h" = "$1" ] || [ "--help" = "$1" ]
then
    echo "介绍: 发布代码到服务器"
    echo "用法: sh $0 PROJECT REVISION"
    echo "参数: PROJECT 该参数是项目的标示，对应配置文件里的conf/conf.PROJECT.sh"
    echo "参数: REVISION 该参数是回退的版本号"
    exit
fi
#############################################################################
#   配置项
#   include lib
this_file=`pwd`"/"$0
REVERT_REVISION=$2
DEPLOY_TOOLS_DIR=`dirname $this_file`"/"
. ${DEPLOY_TOOLS_DIR}common/utils.sh
. ${DEPLOY_TOOLS_DIR}common/common.sh

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
PROJECT_TAG=${TAG_DIR}${PROJECT}.${REVERT_REVISION}"/"
svn export --force -r$CURRENT_REVISION $SVN_URL $PROJECT_TAG > /dev/null
#############################################################################
# 源文件打包
cecho "\n=== 上线文件打包 === \n" $c_notify
cd ${PROJECT_TAG}
rm -f ${DEPLOY_TOOLS_DIR}${PROJECT}.zip
zip -r ${DEPLOY_TOOLS_DIR}${PROJECT}.zip ./ > /dev/null
cd -
#############################################################################
# 打包文件传输
cecho "\n=== 上线文件传输 === \n" $c_notify
for host in $ONLINE_HOSTS
do
    scp ${DEPLOY_TOOLS_DIR}${PROJECT}.zip $SSH_USER@$host:$PUBLIC_DIR
    cecho "传输到$host成功" $c_notify
    ssh $SSH_USER@$host "cd $PUBLIC_DIR;unzip ${PROJECT}.zip -d ${PROJECT}"
    cecho "解压${PROJECT}.zip完成" $c_notify
done
#############################################################################
# 建立软连，执行命令
cecho "\n=== 服务开始变更 === \n" $c_notify
for host in $ONLINE_HOSTS
do
    ssh $SSH_USER@$host "cd $PUBLIC_DIR;ln -T -s $PROJECT $PUBLIC_NAME;$CMD;"
done
#############################################################################
# 发布成功写入记录
`echo "$CURRENT_REVISION" > ${LOG_DIR}${PROJECT}.log`
cecho "\n=== 上线结束 === \n" $c_notify