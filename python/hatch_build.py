from hatchling.builders.hooks.plugin.interface import BuildHookInterface


class CustomBuildHook(BuildHookInterface):
    def initialize(self, version, build_data):
        # 启用平台特定标签
        build_data["infer_tag"] = True
        # 标记为非纯 Python（可选，您的配置文件已设置）
        build_data["pure_python"] = False
