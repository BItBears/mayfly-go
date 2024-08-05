#bin/bash

#----------------------------------------------
# 前后端打包编译至指定目录,即快速制作发行版
#----------------------------------------------

project_path=$(pwd)
# 构建后的二进制执行文件名
exec_file_name="mayfly-go"
# web项目目录
web_folder="${project_path}/mayfly_go_web"
# server目录
server_folder="${project_path}/server"

function echo_red() {
    echo -e "\033[1;31m$1\033[0m"
}

function echo_green() {
    echo -e "\033[1;32m$1\033[0m"
}

function echo_yellow() {
    echo -e "\033[1;33m$1\033[0m"
}

function buildWeb() {
    cd ${web_folder}
    copy2Server=$1

    echo_yellow "-------------------打包前端开始-------------------"
    yarn run build
    if [ "${copy2Server}" == "2" ]; then
        echo_green '将打包后的静态文件拷贝至server/static/static'
        rm -rf ${server_folder}/static/static && mkdir -p ${server_folder}/static/static && cp -r ${web_folder}/dist/* ${server_folder}/static/static
    fi
    echo_yellow ">>>>>>>>>>>>>>>>>>>打包前端结束<<<<<<<<<<<<<<<<<<<<\n"
}

function build() {
    cd ${project_path}

    # 打包产物的输出目录
    toFolder=$1
    os=$2
    arch=$3
    copyDocScript=$4

    echo_yellow "-------------------${os}-${arch}打包构建开始-------------------"

    cd ${server_folder}
    echo_green "打包构建可执行文件..."

    execFileName=${exec_file_name}
    # 如果是windows系统,可执行文件需要添加.exe结尾
    if [ "${os}" == "windows" ]; then
        execFileName="${execFileName}.exe"
    fi
    CGO_ENABLE=0 GOOS=${os} GOARCH=${arch} go build -ldflags="-w" -o ${execFileName} main.go && upx -9 ${execFileName}

    if [ -d ${toFolder} ]; then
        echo_green "目标文件夹已存在,清空文件夹"
        sudo rm -rf ${toFolder}
    fi
    echo_green "创建'${toFolder}'目录"
    mkdir ${toFolder}/{data,logs,ssl,config}

    echo_green "移动二进制文件至'${toFolder}'"
    mv ${server_folder}/${execFileName} ${toFolder}

    # if [ "${copy2Server}" == "1" ] ; then
    #     echo_green "拷贝前端静态页面至'${toFolder}/static'"
    #     mkdir -p ${toFolder}/static && cp -r ${web_folder}/dist/* ${toFolder}/static
    # fi

    if [ "${copyDocScript}" == "1" ]; then
        echo_green "拷贝脚本等资源文件[config.yml.example、mayfly-go.sql、mayfly-go.sqlite、readme.txt、startup.sh、shutdown.sh]"
        cp ${server_folder}/config.yml.example ${toFolder}/config/
        cp ${server_folder}/config.yml.sqlite.example ${toFolder}/config/config-sqlite.yml
        cp ${server_folder}/readme.txt ${toFolder}
        cp ${server_folder}/resources/script/startup.sh ${toFolder}
        cp ${server_folder}/resources/script/shutdown.sh ${toFolder}
        cp ${server_folder}/resources/script/sql/mayfly-go.sql ${toFolder}/data/
        cp ${server_folder}/resources/data/mayfly-go.sqlite ${toFolder}/data/
    fi

    echo_yellow ">>>>>>>>>>>>>>>>>>>${os}-${arch}打包构建完成<<<<<<<<<<<<<<<<<<<<\n"
}

function buildLinuxAmd64() {
    build "$1/mayfly-go-linux-amd64" "linux" "amd64" $2
}

function buildLinuxArm64() {
    build "$1/mayfly-go-linux-arm64" "linux" "arm64" $2
}

function buildWindows() {
    build "$1/mayfly-go-windows" "windows" "amd64" $2
}

function buildMac() {
    build "$1/mayfly-go-mac" "darwin" "amd64" $2
}

function buildDocker() {
    echo_yellow "-------------------构建docker镜像开始-------------------"
    imageVersion=$1
    imageName="mayflygo/mayfly-go:${imageVersion}"
    docker build --platform linux/amd64 -t "${imageName}" .
    echo_green "docker镜像构建完成->[${imageName}]"
    echo_yellow "-------------------构建docker镜像结束-------------------"
}

function buildxDocker() {
    echo_yellow "-------------------docker buildx构建镜像开始-------------------"
    imageVersion=$1
    imageName="ccr.ccs.tencentyun.com/mayfly/mayfly-go:${imageVersion}"
    docker buildx build --push --platform linux/amd64,linux/arm64 -t "${imageName}" .
    echo_green "docker多版本镜像构建完成->[${imageName}]"
    echo_yellow "-------------------docker buildx构建镜像结束-------------------"
}
function buildLinuxAmdArm64() {
    toPath=$1
    copyDocScript=$2
    DesDir=${toPath}/amd_armPkgs
    buildLinuxAmd64 ${toPath} ${copyDocScript}
    buildLinuxArm64 ${toPath} ${copyDocScript}
    versionNumber=$(date +%Y%m%d)
    echo_yellow "-------------------AMD64 and ARM64 构建开始-------------------"
    if [ -d ${DesDir} ]; then
        echo_green "目标文件夹已存在,清空文件夹"
        rm -rf ${DesDir}
    fi
    mkdir -p ${DesDir}/mayfly-go
    cp ${server_folder}/resources/script/install.sh.example ${DesDir}/mayfly-go_Install_amd64_arm64.sh
    cp -rf ${toPath}/mayfly-go-linux-amd64/* ${DesDir}/mayfly-go
    mv ${DesDir}/mayfly-go/mayfly-go ${DesDir}/mayfly-go/mayfly-go.amd64
    mv ${toPath}/mayfly-go-linux-arm64/mayfly-go ${DesDir}/mayfly-go/mayfly-go.arm64
    rm -rf ${toPath}/mayfly-go-linux-amd64
    rm -rf ${toPath}/mayfly-go-linux-arm64
    pwd=$(pwd)
    cd ${DesDir}
    tar zcf mayfly-go-amdarm.tar.gz mayfly-go
    md5num=$(md5sum mayfly-go-amdarm.tar.gz | awk '{print $1}')
    echo "sed -i 's|mayfly-go-MD5|${md5num}|g' ${DesDir}/mayfly-go_Install_amd64_arm64.sh" | bash
    base64 mayfly-go-amdarm.tar.gz >>${DesDir}/mayfly-go_Install_amd64_arm64.sh
    cd ${pwd}
    echo_yellow "-------------------AMD64 and ARM64 构建结束-------------------"
}
function runBuild() {
    read -p "请选择构建版本[0|其他->除docker镜像外其他 1->linux-amd64 2->linux-arm64 3->windows 4->mac 5->docker 6->docker buildx 7->amd64-arm64(autoinstall)]: " buildType

    toPath="."
    imageVersion="latest"
    copyDocScript="1"

    if [[ "${buildType}" != "5" ]] && [[ "${buildType}" != "6" ]]; then
        # 构建结果的目的路径
        read -p "请输入构建产物输出目录[默认当前路径]: " toPath
        if [ ! -d ${toPath} ]; then
            echo_red "构建产物输出目录不存在!"
            exit
        fi
        if [ "${toPath}" == "" ]; then
            toPath="."
        fi

        read -p "是否拷贝文档&脚本[0->否 1->是][默认是]: " copyDocScript
        if [ "${copyDocScript}" == "" ]; then
            copyDocScript="1"
        fi

        # 进入目标路径,并赋值全路径
        cd ${toPath}
        toPath=$(pwd)

        # read -p "是否构建前端[0|其他->否 1->是 2->构建并拷贝至server/static/static]: " runBuildWeb
        runBuildWeb="2"
        # 编译web前端
        buildWeb ${runBuildWeb}
    fi

    if [[ "${buildType}" == "5" ]] || [[ "${buildType}" == "6" ]]; then
        read -p "请输入docker镜像版本号[默认latest]: " imageVersion

        if [ "${imageVersion}" == "" ]; then
            imageVersion="latest"
        fi
    fi

    case ${buildType} in
    "1")
        buildLinuxAmd64 ${toPath} ${copyDocScript}
        ;;
    "2")
        buildLinuxArm64 ${toPath} ${copyDocScript}
        ;;
    "3")
        buildWindows ${toPath} ${copyDocScript}
        ;;
    "4")
        buildMac ${toPath} ${copyDocScript}
        ;;
    "5")
        buildDocker ${imageVersion}
        ;;
    "6")
        buildxDocker ${imageVersion}
        ;;
    "7")
        buildLinuxAmdArm64 ${toPath} ${copyDocScript}
        ;;
    *)
        buildLinuxAmd64 ${toPath} ${copyDocScript}
        buildLinuxArm64 ${toPath} ${copyDocScript}
        buildWindows ${toPath} ${copyDocScript}
        buildMac ${toPath} ${copyDocScript}
        ;;
    esac

    if [[ "${buildType}" != "5" ]] && [[ "${buildType}" != "6" ]]; then
        echo_green "删除['${server_folder}/static/static']下静态资源文件."
        # 删除静态资源文件，保留一个favicon.ico，否则后端启动会报错
        rm -rf ${server_folder}/static/static/assets
        rm -rf ${server_folder}/static/static/config.js
        rm -rf ${server_folder}/static/static/index.html
    fi
}

runBuild
