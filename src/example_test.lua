-- 文件名 *_test.lua
function player_creation_test()
    local p = { name = "Alice", hp = 100 }
    assert(p.name == "Alice", "Name should be Alice") -- pass
    assert(p.hp == 90, "HP should be 90")             -- fail
end

function player_damage_test()
    local p = { hp = 100 }
    p.hp = p.hp - 20
    assert(p.hp == 80, "HP should be 80")             -- pass
end
