;; 文件名： player-tests.fnl (或其他 *_test.fnl)

;; 注意：在 Fennel 中，字符串使用双引号 " "，而不是 Lua 的 [[ ]] 或 ' '

(fn player-creation-test []
  (local p {:name "Alice" :hp 100})
  
  ;; 1. 检查名字
  (assert (= p.name "Alice") "Name should be Alice") ; pass
  
  ;; 2. 检查生命值
  (assert (= p.hp 90) "HP should be 90")) ; fail (因为 100 不等于 90)


(fn player-damage-test []
  (local p {:hp 100})
  
  ;; 使用 'set' 来修改本地变量 table 的字段
  ;; (= 100 - 20) 是 80
  (tset p :hp (- p.hp 20))
  
  ;; 检查生命值
  (assert (= p.hp 80) "HP should be 80")) ; pass