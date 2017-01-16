echo "$DEVOPS_BRANCH";
if [ -z "$DEVOPS_BRANCH" ]; then
	export DEVOPS_BRANCH="master";
fi;
echo "Cloning from devops [branch: $DEVOPS_BRANCH]";
git clone -b $DEVOPS_BRANCH https://github.com/project-renard/devops.git external/project-renard/devops;
export MY_DEVOPS_DIR="./external/project-renard/devops";

DOC_OUTPUT="_generated_api/doc/development/api";
mkdir -p $DOC_OUTPUT;
bash $MY_DEVOPS_DIR/script/build-doc-site $DOC_OUTPUT;
