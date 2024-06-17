## 🗿 整個人都硬起來ㄌ 
> [!WARNING]  
> 本地運行需要先修改 `judge.sh` 裡的路徑
> ```
> #!/bin/bash
> input_dir="{{你ㄉ專案路徑}}/input"
> result_dir="{{你ㄉ專案路徑}}/result"
> answer_dir="{{你ㄉ專案路徑}}/answer"
> compiler="{{你ㄉ專案路徑}}/build/out/compiler"
> ...
> ```


### 測試作業二的輸出到螢幕

```bash
make clean
make build
./build/out/compiler input/subtask01-helloworld/testcase04.cpp ./code.txt
```

### Judge 單筆測資

```bash
./judge.sh --case=subtask01-helloworld/testcase01
```