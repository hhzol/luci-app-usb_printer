--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth
Copyright 2005-2013 hackpascal

Licensed under the Apache License, Version 2.0
]]--

require "luci.util"
local uci = luci.model.uci.cursor_state()
local net = require "luci.model.network"

m = Map("usb_printer", translate("USB Printer Server"),
    translate("Shares multiple USB printers via TCP/IP.<br />" ..
              "When modified bindings, re-plug USB connectors to take effect.<br />" ..
              "This module requires kmod-usb-printer."))

----------------------------------------------------------
-- 工具函数
----------------------------------------------------------

local function hex_align(hex, num)
    local len = num - string.len(hex)
    return string.rep("0", len) .. hex
end

----------------------------------------------------------
-- 检测 USB 打印机
----------------------------------------------------------

local function detect_usb_printers()
    local data = {}
    local lps = luci.util.execi("/usr/bin/detectlp")

    for value in lps do
        local row = {}

        -- detectlp 输出：
        -- device, VID/PID/?, model, description

        local pos = string.find(value, ",")
        local devname = string.sub(value, 1, pos - 1)
        value = string.sub(value, pos + 1)

        pos = string.find(value, ",")
        local product = string.sub(value, 1, pos - 1)
        value = string.sub(value, pos + 1)

        pos = string.find(value, ",")
        local model = string.sub(value, 1, pos - 1)
        local name = string.sub(value, pos + 1)

        pos = string.find(product, "/")
        local vid = string.sub(product, 1, pos - 1)
        local pid = string.sub(product, pos + 1)
        pos = string.find(pid, "/")
        pid = string.sub(pid, 1, pos - 1)

        row.description = name
        row.model = model
        row.id = hex_align(vid, 4) .. ":" .. hex_align(pid, 4)
        row.name = devname
        row.product = product

        table.insert(data, row)
    end

    return data
end

----------------------------------------------------------
-- 已检测的打印机列表
----------------------------------------------------------

local printers = detect_usb_printers()

v = m:section(Table, printers, translate("Detected printers"))
v:option(DummyValue, "description", translate("Description"))
v:option(DummyValue, "model", translate("Printer Model"))
v:option(DummyValue, "id", translate("VID/PID"))
v:option(DummyValue, "name", translate("Device Name"))

----------------------------------------------------------
-- 绑定配置
----------------------------------------------------------

local netm = net.init(m.uci)

s = m:section(TypedSection, "printer", translate("Bindings"))
s.addremove = true
s.anonymous = true

s:option(Flag, "enabled", translate("Enable"))

-- USB 设备
d = s:option(Value, "device", translate("Device"))
d.rmempty = true
for _, item in ipairs(printers) do
    d:value(item.product, item.description .. " [" .. item.id .. "]")
end

-- 监听接口（★ 修复重点）
b = s:option(ListValue, "bind", translate("Interface"),
    translate("Specifies the interface to listen on."))
b.rmempty = true

for _, n in ipairs(netm:get_networks()) do
    b:value(n:name(), n:name())
end

-- 端口
p = s:option(ListValue, "port", translate("Port"),
    translate("TCP listener port.")) 
p.rmempty = true
for i = 9100, 9109 do
    p:value(i, tostring(i))
end

s:option(Flag, "bidirectional", translate("Bidirectional mode"))

return m
