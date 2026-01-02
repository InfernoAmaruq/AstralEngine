function lovr.load()
    if not lovr.graphics then
        print(string.format("Astral Engine %d.%d.%d\nNo game", lovr.getVersion()))
        lovr.event.quit()
        return
    end

    if not lovr.headset or lovr.headset.getPassthrough() == "opaque" then
        lovr.graphics.setBackgroundColor(0x20232c)
    end

    logo = lovr.graphics.newTexture("AstralIcon.png")
end

function lovr.draw(pass)
    local padding = 0.1
    local font = lovr.graphics.getDefaultFont()
    local fade = 0.315 + 0.685 * math.abs(math.sin(lovr.timer.getTime() * 2))
    local titlePosition = 1.5 - padding
    local subtitlePosition = titlePosition - font:getHeight() * 0.25 - padding

    pass:draw(logo,0,2,-3)

    pass:text("ASTRAL", -0.012, titlePosition, -3, 0.25, quat(0, 0, 1, 0), nil, "center", "top")

    pass:setColor(0.9, 0.9, 0.9, fade)
    pass:text(
        "In the beginning... there was nothing",
        -0.005,
        subtitlePosition,
        -3,
        0.15,
        0,
        0,
        1,
        0,
        nil,
        "center",
        "top"
    )
end

function lovr.keypressed(key)
    if key == "escape" then
        lovr.event.quit()
    end
end
