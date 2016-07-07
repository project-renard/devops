if [ -z "$DEVOPS_BRANCH" ]; then
	export DEVOPS_BRANCH="master";
fi;
echo "Cloning from devops [branch: $DEVOPS_BRANCH]";
git clone -b $DEVOPS_BRANCH https://github.com/project-renard/devops.git external/project-renard/devops;
export MY_DEVOPS_DIR="./external/project-renard/devops";
. $MY_DEVOPS_DIR/script/travis-ci-before-install.sh;
