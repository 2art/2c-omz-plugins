# precise-timer plugin

This plugin adds a timer that times each executed command with down to nanoseconds acuracy, and then displays the time in right prompt.

![Preview](precise-timer.preview.png?raw=true "Timer RPrompt Preview")

# Installation

## 1. Single Directory Clone (Sparse Clone)

Git hasn't made it easy to clone single directories. Luckily, it's now available via sparse clones, but it requires a few steps, listed below:

```bash
mkdir $ZSH_CUSTOM/plugins/precise-timer
cd $ZSH_CUSTOM/plugins/precise-timer
git init
git config core.sparseCheckout true
git remote add -f origin https://github.com/2art/omz-plugins.git
echo "precise-timer/*" > .git/info/sparse-checkout
git checkout main
```

## 2. Clone Whole Repository

- Modify the target path to whatever suits you.

```bash
git clone https://github.com/2art/omz-plugins.git ~/.2art-omz-plugins
cp -r ~/.2art-omz-plugins/precise-timer $ZSH_CUSTOM/plugins
```

- Enable plugin in .zshrc: `plugins=( precise-timer )`

## 3. Manual Copy-Pasta Style

- Ensure that `$ZSH_CUSTOM` points to the directory containing `plugins/`
- Copy the raw plugin file from [here](https://github.com/2art/omz-plugins/blob/main/precise-timer/precise-timer.plugin.zsh) and save it to `$ZSH_CUSTOM/precise-timer/precise-timer.plugin.zsh`
- Enable plugin in `.zshrc`: `plugins=( precise-timer )`
