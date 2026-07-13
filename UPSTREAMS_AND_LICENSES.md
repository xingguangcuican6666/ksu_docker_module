# ksu_docker_module 项目总结与上游许可

## 项目概览

这是一个把 Docker 运行时打包进 KernelSU 模块的项目。

- 安装阶段会检查内核 `cgroup`、`ipc`、`pid`、`userns` 等能力。
- 启动阶段会创建 `/dev/docker`，挂载 cgroup，并拉起 `dockerd`。
- WebUI 通过 `scripts/dockerctl.sh` 管理 `daemon.json`、`settings.json`、状态和日志。

## 仓库自有代码

- `post-fs-data.sh`
- `service.sh`
- `customize.sh`
- `scripts/dockerctl.sh`
- `webroot/` 下的前端打包产物

根目录 `LICENSE` 为 GPL-3.0。

## 已识别的上游仓库

| 组件 | 上游仓库 | 许可证 |
| --- | --- | --- |
| Docker Engine | https://github.com/moby/moby | Apache-2.0 |
| Docker CLI | https://github.com/docker/cli | Apache-2.0 |
| Docker networking proxy | https://github.com/moby/libnetwork | Apache-2.0 |
| containerd | https://github.com/containerd/containerd | Apache-2.0 |
| runc | https://github.com/opencontainers/runc | Apache-2.0 |
| tini | https://github.com/krallin/tini | MIT |
| LVM2 / device-mapper | https://github.com/lvmteam/lvm2 | GPL-2.0, BSD-2-Clause, LGPL-2.1 |
| GNU Bash | https://git.savannah.gnu.org/git/bash.git | GPL-3.0-or-later |
| libandroid-support | https://github.com/termux/libandroid-support | MIT, Apache-2.0, BSD-2-Clause, Public Domain |
| wcwidth | https://github.com/jquast/wcwidth | MIT |
| `@m3e/web` | https://github.com/matraic/m3e | MIT |
| `lit` family | https://github.com/lit/lit | BSD-3-Clause |
| `tslib` | https://github.com/Microsoft/tslib | 0BSD |
| `vite` | https://github.com/vitejs/vite | MIT |
| `esbuild` | https://github.com/evanw/esbuild | MIT |
| `rollup` | https://github.com/rollup/rollup | MIT |
| `material-color-utilities` | https://github.com/material-foundation/material-color-utilities | Apache-2.0 |

## 证据来源

- `system/libexec/dockerd`、`system/bin/docker.real`、`system/bin/containerd`、`system/bin/runc` 的 Go build info
- `system/bin/docker-init`、`system/bin/bash` 的字符串信息
- `system/share/doc/libandroid-support/LICENSE.txt`
- `package.json`、`package-lock.json`

## 备注

- `system/share/doc/containerd/copyright`、`system/share/doc/docker/copyright`、`system/share/doc/runc/copyright` 当前是指向 `LICENSES/*.txt` 的 symlink，但仓库里未包含 `LICENSES/` 目录。
- `package-lock.json` 还有大量传递依赖；如果要做完整 SBOM，建议再按 lockfile 递归导出。
