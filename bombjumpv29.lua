local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local sharedEnv = type(getgenv) == "function" and getgenv() or _G

if type(sharedEnv.__StandaloneBombJumpFireflyCleanup) == "function" then
    pcall(sharedEnv.__StandaloneBombJumpFireflyCleanup)
end
if type(sharedEnv.__StandaloneBombJumpFireflyDiagnosticsCleanup) == "function" then
    pcall(sharedEnv.__StandaloneBombJumpFireflyDiagnosticsCleanup)
end
-- Recover controls if the previously executed v13 left PlayerModule controls disabled.
pcall(function()
    local previousControls = sharedEnv.__StandaloneBombJumpFireflyMovementControls
    if previousControls then
        previousControls:Enable()
    end
    sharedEnv.__StandaloneBombJumpFireflyMovementControls = nil
end)
sharedEnv.__StandaloneBombJumpFireflyCleanup = nil

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

-- Diagnostic-only panel. Stored in one namespace to avoid increasing the
-- script's long-lived top-level local count (Luau has a per-function local limit).
local fireflyDiag = {}
do
    local state = fireflyDiag
    local function initialize()
        local function number(value, fallback)
            return type(value) == "number" and value == value and math.abs(value) < math.huge and value or fallback
        end
        local history = sharedEnv.__StandaloneBombJumpFireflyDiagnosticHistory
        if type(history) ~= "table" or type(history.lines) ~= "table" then
            history = {lines = {}, startedAt = os.clock()}
            sharedEnv.__StandaloneBombJumpFireflyDiagnosticHistory = history
        end
        history.startedAt = number(history.startedAt, os.clock())
        history.attempts = math.max(0, math.floor(number(history.attempts, 0)))
        history.clears = math.max(0, math.floor(number(history.clears, 0)))
        history.runs = math.max(0, math.floor(number(history.runs, 0))) + 1
        state.history, state.lines, state.startedAt = history, history.lines, history.startedAt
        history.owner = state
        state.build = "firefly-workbench-v1"
        state.fileName = "firefly_jar_diagnostics.txt"
        state.connections, state.records, state.attempts, state.order = {}, {}, {}, {}
        state.view, state.page, state.follow = "summary", 1, true
        state.pageSize, state.detailed = 45, false
        state.enabled, state.stopped = false, false
        local colors = {
            window = Color3.fromRGB(13, 17, 23), header = Color3.fromRGB(22, 27, 34),
            border = Color3.fromRGB(48, 54, 61), text = Color3.fromRGB(230, 237, 243),
            muted = Color3.fromRGB(139, 148, 158), accent = Color3.fromRGB(126, 231, 135),
            warn = Color3.fromRGB(227, 179, 65), error = Color3.fromRGB(255, 123, 114),
            button = Color3.fromRGB(33, 38, 45), blue = Color3.fromRGB(121, 192, 255),
        }
        state.colors = colors
        local names = {
            DIAG_SESSION = "Sessão iniciada", FIREFLY_MODE = "Diagnóstico ativo", DIAG = "Histórico limpo",
            ACTIVATION_BEGIN = "Início da tentativa", ARM_SENSOR = "Sensor do braço pronto",
            ACTIVATION_PATH = "Caminho de ativação", TOOL_ACTIVATED = "Jar ativado",
            ACTIVATION_RESULT = "Retorno da ativação", PLAYER_LOCK_BEGIN = "Controle automático iniciado",
            SEQUENCE_BEGIN = "Animação reconhecida", FIRST_TAKEOFF_CONFIRMED = "Primeiro salto confirmado",
            LID_BOUND = "Tampa identificada", MOVE_WINDOW_BEGIN = "Janela de aproximação",
            FIRST_DESCENT_OBSERVED = "Descida observada", FIRST_LANDING_OBSERVED = "Primeiro pouso observado",
            LANDED_STATE = "Superfície do pouso", LID_LANDING_HANDLER = "Contato com a tampa",
            LID_PHYSICS_CONTACT = "Contato físico com a tampa", LID_JUMP_REQUEST = "Segundo salto solicitado",
            JUMP_REQUEST_SENT = "Comando de salto enviado", POST_DESCENT_TAKEOFF = "Segundo impulso confirmado",
            RELEASE_HANDLER_ENTER = "Verificando liberação", PLAYER_UNLOCK_DONE = "Controles restaurados",
            AUTO_MOVE_STOP = "Correção de movimento encerrada", ATTEMPT_FINISH = "Tentativa encerrada",
            ACTIVATION_ERROR = "Erro de ativação", ACTIVATION_FAILED = "Ativação falhou",
            ARM_SENSOR_FAILED = "Sensor indisponível", AUTO_MOVE_FAILURE = "Aproximação interrompida",
            MOVE_WINDOW_EXPIRED = "Janela de movimento encerrada", LID_REJECTED = "Tampa descartada",
        }
        local traceTags = {
            ARM_TRACE = true, AUTO_TRACE = true, AUTO_TRACE_WAIT = true, AUTO_TRACE_CLIMB = true,
            PHYSICS_CHECK = true, STATE_EVENT = true, JUMPING_EVENT = true,
            JUMP_REQUEST_ISSUE = true, JUMP_EVENT_WAIT_IMPULSE = true, STATE_EVENT_WAIT_IMPULSE = true,
            JUMP_FLAG_CLEAR = true, LID_LANDING_HANDLER = true, RELEASE_HANDLER_SKIP = true,
        }
        local function fields(detail)
            local values = {}
            for segment in detail:gmatch("[^;]+") do
                local key, value = segment:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
                if key then values[key] = value end
            end
            return values
        end
        local function vector(value)
            if type(value) ~= "string" then return nil end
            local components = {}
            for item in value:gmatch("[-+]?%d*%.?%d+") do components[#components + 1] = tonumber(item) end
            return components
        end
        local function condition(values)
            local velocity, look = vector(values.velocity), vector(values.facing)
            if not velocity or #velocity < 3 then return "movimento não registrado" end
            local x, z = velocity[1], velocity[3]
            local speed = math.sqrt(x * x + z * z)
            if speed < 0.5 then return "parado" end
            if not look or #look < 2 then return string.format("movimento %.1f studs/s", speed) end
            local length = math.sqrt(look[1] * look[1] + look[2] * look[2])
            if length < 0.01 then return "em movimento" end
            local dot = (x * look[1] + z * look[2]) / (speed * length)
            if dot > 0.85 then return "para frente" end
            if dot < -0.85 then return "para trás" end
            if math.abs(dot) < 0.35 then return "lateral" end
            return "diagonal"
        end
        local function attemptFor(id, time)
            local attempt = state.attempts[id]
            if not attempt then
                attempt = {id = id, start = time, last = time, status = "EM CURSO", reason = "Aguardando os próximos eventos",
                    records = {}, flags = {}, condition = "movimento não registrado"}
                state.attempts[id] = attempt
                if id > 0 then state.order[#state.order + 1] = id end
            end
            return attempt
        end
        local function ingest(line, fallbackAttempt)
            local elapsed, tag, detail = line:match("^%+([%d%.]+)s%s*|%s*([^|]-)%s*|%s*(.*)$")
            if not elapsed then
                elapsed, tag = line:match("^%+([%d%.]+)s%s*|%s*(.-)%s*$")
                detail = ""
            end
            if not elapsed then elapsed, tag, detail = "0", "LEGACY_RECORD", line end
            local explicit = detail:match("^attempt=(%d+)")
            local id = tonumber(explicit) or fallbackAttempt or 0
            detail = detail:gsub("^attempt=%d+;%s*", ""):gsub("^attempt=%d+$", "")
            local record = {index = #state.records + 1, time = tonumber(elapsed) or 0,
                tag = tag, detail = detail, attempt = id, trace = traceTags[tag] == true}
            record.level = (tag:find("ERROR", 1, true) or tag:find("FAILED", 1, true) or tag == "AUTO_MOVE_FAILURE") and "ERRO"
                or (tag == "ATTEMPT_FINISH" or tag:find("EXPIRED", 1, true) or tag:find("ABORT", 1, true)) and "AVISO"
                or "INFO"
            state.records[#state.records + 1] = record
            local attempt = attemptFor(id, record.time)
            attempt.last = record.time
            attempt.records[#attempt.records + 1] = record
            local values = tag == "ACTIVATION_BEGIN" and fields(detail) or {}
            local flags = attempt.flags
            if tag == "ACTIVATION_BEGIN" then
                attempt.start, attempt.condition, attempt.ping = record.time, condition(values), values.ping
            elseif tag == "TOOL_ACTIVATED" then flags.activation = true
            elseif tag == "SEQUENCE_BEGIN" then flags.animation = true
            elseif tag == "FIRST_TAKEOFF_CONFIRMED" then flags.first = true
            elseif tag == "LID_BOUND" then flags.lid = true
            elseif tag == "LID_JUMP_REQUEST" then flags.contact, flags.request = true, true
            elseif tag == "POST_DESCENT_TAKEOFF" then flags.impulse = true
            elseif tag == "RELEASE_HANDLER_ENTER" then
                if detail:find("source=jump event with upward impulse", 1, true)
                    or detail:find("source=state event with upward impulse", 1, true)
                    or detail:find("source=physics impulse confirmed by player ascent", 1, true) then flags.impulse = true end
            elseif tag == "PLAYER_UNLOCK_DONE" then
                flags.controls = true
                if flags.request and flags.impulse then
                    attempt.status, attempt.reason = "CONFIRMADO", "Contato e segundo impulso registrados"
                else
                    attempt.status, attempt.reason = "INCONCLUSIVO", "Controles liberados sem prova completa do segundo salto na tampa"
                end
            end
            if tag == "ATTEMPT_FINISH" or tag == "ACTIVATION_FAILED" or tag == "ACTIVATION_ERROR"
                or tag == "ARM_SENSOR_FAILED" or tag == "AUTO_MOVE_FAILURE" then
                attempt.status, attempt.reason, attempt.errorTag = "FALHOU", detail, tag
            elseif tag == "ACTIVATION_CANCELLED" then
                attempt.status, attempt.reason, attempt.errorTag = "CANCELADO", detail, tag
            end
            return record
        end
        local legacyAttempt = 0
        for index, value in ipairs(history.lines) do
            local line = tostring(value)
            history.lines[index] = line
            if line:find("| ACTIVATION_BEGIN |", 1, true) and not line:find("attempt=", 1, true) then legacyAttempt += 1 end
            local record = ingest(line, legacyAttempt)
            history.attempts = math.max(history.attempts, record.attempt)
        end
        if #history.lines > 0 and not tostring(history.lines[1]):find("| DIAG", 1, true) then
            state.legacyNotice = "O histórico importado começa no meio da sessão; registros já descartados por versões antigas não podem ser reconstruídos."
        end
        state.selected = state.order[#state.order] or 0
        local function resultColor(attempt)
            if attempt and attempt.status == "CONFIRMADO" then return colors.accent end
            if attempt and attempt.status == "FALHOU" then return colors.error end
            if attempt and (attempt.status == "INCONCLUSIVO" or attempt.status == "CANCELADO") then return colors.warn end
            return colors.blue
        end
        local function outcomeReason(attempt)
            local reason = attempt.reason
            if reason:find("landed off lid", 1, true) then return "O primeiro pouso terminou fora da tampa; não há segundo salto confirmado." end
            if reason:find("second jump failed", 1, true) then return "O segundo salto foi solicitado, mas o impulso não foi confirmado dentro da janela." end
            if reason:find("first jump not detected", 1, true) then return "O primeiro salto foi solicitado, mas a saída do chão não foi confirmada." end
            if reason:find("lid not detected", 1, true) then return "Nenhuma tampa válida apareceu dentro da janela de busca." end
            if reason:find("right arm trigger timed out", 1, true) then return "A animação esperada do braço não foi reconhecida dentro da janela." end
            return reason
        end
        local function summary(attempt)
            if not attempt or attempt.id == 0 then
                return "AGUARDANDO TENTATIVA\n\nSelecione Firefly Jar e use o botão de salto.\nCada tentativa terá resultado, etapas e eventos próprios.\n\nCOPIAR TUDO inclui todas as tentativas e todos os registros.\nLIMPAR é a única ação que apaga este histórico."
            end
            local lines = {
                string.format("TENTATIVA #%03d  /  %s", attempt.id, attempt.status), "", outcomeReason(attempt), "",
                "Movimento     " .. attempt.condition,
                "Ping          " .. (attempt.ping or "não registrado"),
                string.format("Duração       %.3f s", math.max(0, attempt.last - attempt.start)),
                string.format("Registros     %d", #attempt.records), "", "ETAPAS OBSERVADAS", "",
            }
            local stages = {{"activation", "Jar ativado"}, {"animation", "Animação reconhecida"},
                {"first", "Primeiro salto"}, {"lid", "Tampa identificada"}, {"contact", "Contato na tampa"},
                {"request", "Segundo salto solicitado"}, {"impulse", "Segundo impulso"}, {"controls", "Controles liberados"}}
            for _, stage in ipairs(stages) do
                lines[#lines + 1] = string.format("  %-13s %s", attempt.flags[stage[1]] and "OK" or "não observado", stage[2])
            end
            if attempt.errorTag then lines[#lines + 1] = "Origem: " .. attempt.errorTag end
            lines[#lines + 1] = "\nEtapa não observada não significa causa comprovada."
            return table.concat(lines, "\n")
        end
        state.summary = summary
        local function wrap(text, columns)
            local output = {}
            for line in (text .. "\n"):gmatch("(.-)\n") do
                if #line <= columns then output[#output + 1] = line
                else
                    local indent, current = line:match("^%s*") or "", ""
                    for word in line:gmatch("%S+") do
                        if #current > #indent and #current + #word + 1 > columns then
                            output[#output + 1], current = current, indent .. word
                        else current = current == "" and (indent .. word) or current .. " " .. word end
                    end
                    output[#output + 1] = current
                end
            end
            return table.concat(output, "\n")
        end
        local function eventDetail(record, attempt)
            if record.tag == "ACTIVATION_BEGIN" and attempt then
                return attempt.condition .. " / ping " .. (attempt.ping or "n/d")
            end
            if record.tag == "ATTEMPT_FINISH" and attempt then return outcomeReason(attempt) end
            if record.tag == "PLAYER_UNLOCK_DONE" and attempt then return attempt.status .. " / " .. attempt.reason end
            if record.tag == "ARM_SENSOR" then
                local values = fields(record.detail)
                return (values.rig or "rig n/d"):gsub("Enum.HumanoidRigType%.", "") .. " / " .. (values.sensor or "sensor n/d")
            end
            return (record.detail:match("^[^;]+") or record.detail)
                :gsub("Enum.HumanoidStateType%.", ""):gsub("Enum.Material%.", "")
        end
        state.export = function()
            local output = {
                "FIREFLY JAR / DIAGNÓSTICO COMPLETO", "Build: " .. state.build,
                string.format("Execuções: %d | Tentativas: %d | Registros: %d | Limpezas explícitas: %d",
                    history.runs, #state.order, #history.lines, history.clears),
                "Retenção: sem descarte automático. Os registros brutos abaixo são integrais.",
            }
            if state.legacyNotice then output[#output + 1] = "Aviso de importação: " .. state.legacyNotice end
            output[#output + 1] = "\nÍNDICE DAS TENTATIVAS"
            for _, id in ipairs(state.order) do
                local item = state.attempts[id]
                output[#output + 1] = string.format("#%03d | %-12s | %s | ping %s | %.3f s | %d eventos",
                    id, item.status, item.condition, item.ping or "n/d", math.max(0, item.last - item.start), #item.records)
            end
            for _, id in ipairs(state.order) do output[#output + 1] = "\n" .. summary(state.attempts[id]) end
            output[#output + 1] = "\nREGISTROS BRUTOS INTEGRAIS / ORDEM CRONOLÓGICA\n"
            output[#output + 1] = table.concat(history.lines, "\n")
            return table.concat(output, "\n")
        end
        state.persist = function()
            if history.owner ~= state or #history.lines == 0 or type(writefile) ~= "function" then return false end
            local ok = pcall(writefile, state.fileName, state.export())
            state.fileSaved = ok
            return ok
        end
        local function status(message)
            state.notice = message
            if state.statusLabel then state.statusLabel.Text = message end
        end
        state.status = status
        local function connect(signal, callback)
            local connection = signal:Connect(callback)
            state.connections[#state.connections + 1] = connection
            return connection
        end
        local function stopGui()
            state.drag = nil
            for _, connection in ipairs(state.connections) do pcall(function() connection:Disconnect() end) end
            state.connections = {}
            if state.gui then pcall(function() state.gui:Destroy() end) end
            state.gui, state.textLabel, state.scroll, state.statusLabel = nil, nil, nil, nil
        end
        local function viewport()
            local camera = Workspace.CurrentCamera
            local size = camera and camera.ViewportSize
            if size and size.X > 0 and size.Y > 0 then return size.X, size.Y end
            return 640, 360
        end
        state.viewport = viewport
        local function ui(class, name, parent, properties)
            local object = Instance.new(class)
            object.Name = name
            for key, value in pairs(properties or {}) do object[key] = value end
            object.Parent = parent
            return object
        end
        local function label(name, parent, text, size, color)
            return ui("TextLabel", name, parent, {BackgroundTransparency = 1, BorderSizePixel = 0,
                Font = Enum.Font.Code, Text = text, TextSize = size or 12, TextColor3 = color or colors.text,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd})
        end
        local function button(name, parent, text, callback)
            local object = ui("TextButton", name, parent, {BorderSizePixel = 0, BackgroundColor3 = colors.button,
                TextColor3 = colors.text, Font = Enum.Font.Code, TextSize = 12, Text = text,
                AutoButtonColor = true})
            ui("UICorner", "Corner", object, {CornerRadius = UDim.new(0, 4)})
            connect(object.Activated, callback)
            return object
        end
        local function setRect(object, x, y, width, height)
            object.Position = UDim2.fromOffset(x, y)
            object.Size = UDim2.fromOffset(math.max(0, width), math.max(0, height))
        end
        local function render()
            state.refreshQueued = false
            if state.stopped or not state.enabled or not state.gui or not state.panel.Visible then return end
            local attempt = state.attempts[state.selected]
            state.sessionLabel.Text = string.format("SESSION %02d  /  %d tentativas  /  %d registros", history.runs, #state.order, #history.lines)
            state.resultLabel.Text = attempt and attempt.id > 0 and string.format("#%03d  %s", attempt.id, attempt.status) or "AGUARDANDO"
            state.resultLabel.TextColor3 = resultColor(attempt)
            state.attemptLabel.Text = attempt and attempt.id > 0 and ("#" .. string.format("%03d", attempt.id) .. "  " .. attempt.condition) or "Nenhuma tentativa"
            local content, pageCount = "", 1
            if state.view == "summary" then
                content = summary(attempt)
            else
                local records = attempt and attempt.records or state.records
                local visible = {}
                for _, record in ipairs(records) do
                    if state.view == "raw" or state.detailed or not record.trace then visible[#visible + 1] = record end
                end
                pageCount = math.max(1, math.ceil(#visible / state.pageSize))
                state.page = math.clamp(state.page, 1, pageCount)
                local output = {}
                local first = (state.page - 1) * state.pageSize + 1
                local last = math.min(#visible, first + state.pageSize - 1)
                for i = first, last do
                    local record = visible[i]
                    local elapsed = record.time - (attempt and attempt.start or 0)
                    if state.view == "raw" then
                        output[#output + 1] = history.lines[record.index]
                    else
                        output[#output + 1] = string.format("%7.3f  %-5s  %s", elapsed, record.level, names[record.tag] or record.tag)
                        output[#output + 1] = "         " .. (state.detailed and record.detail:gsub(";%s*", "\n         ")
                            or eventDetail(record, attempt))
                        output[#output + 1] = ""
                    end
                end
                content = #output > 0 and table.concat(output, "\n") or "Nenhum evento nesta seleção."
            end
            state.pageLabel.Text = state.view == "summary" and "RESUMO" or string.format("PÁGINA %d/%d", state.page, pageCount)
            state.pageCount = pageCount
            state.detailButton.Text = state.detailed and "DETALHES ON" or "DETALHES OFF"
            for key, tab in pairs(state.tabs) do
                tab.TextColor3 = key == state.view and colors.accent or colors.muted
                tab.BackgroundColor3 = key == state.view and colors.header or colors.window
            end
            if state.view ~= "raw" then content = wrap(content, math.max(16, math.floor((state.codeWidth - 10) / 7.3))) end
            local renderKey = table.concat({tostring(state.selected), state.view, tostring(state.page), tostring(state.detailed)}, ":")
            local resetScroll = state.renderedKey ~= renderKey
            state.renderedKey = renderKey
            if state.renderedText ~= content then
                state.renderedText = content
                state.textLabel.Text = content
                local count, longest = 1, 0
                for line in (content .. "\n"):gmatch("(.-)\n") do count += 1; longest = math.max(longest, #line) end
                local height = math.max(state.codeHeight, count * 17 + 20)
                local width = math.max(state.codeWidth, longest * 7.3 + 28)
                state.textLabel.Size = UDim2.fromOffset(width, height)
                state.scroll.CanvasSize = UDim2.fromOffset(width + 8, height + 8)
                local previousScroll = state.scroll.CanvasPosition or Vector2.zero
                state.scroll.CanvasPosition = resetScroll and Vector2.zero or Vector2.new(
                    math.clamp(previousScroll.X, 0, math.max(0, width + 8 - state.scroll.Size.X.Offset)),
                    math.clamp(previousScroll.Y, 0, math.max(0, height + 8 - state.scroll.Size.Y.Offset)))
            elseif resetScroll then
                state.scroll.CanvasPosition = Vector2.zero
            end
        end
        state.refresh = render
        local function requestRefresh()
            if state.refreshQueued or state.stopped or not state.enabled or not state.gui then return end
            state.refreshQueued = true
            task.defer(function()
                local ok, err = pcall(render)
                if not ok then state.refreshQueued = false; status("Erro de exibição: " .. tostring(err)) end
            end)
        end
        state.requestRefresh = requestRefresh
        local function layout()
            if not state.gui then return end
            local vw, vh = viewport()
            local maxWidth, maxHeight = math.max(1, vw - 20), math.max(1, vh - 20)
            state.width = math.clamp(state.width or math.min(740, maxWidth), math.min(300, maxWidth), maxWidth)
            state.height = math.clamp(state.height or math.min(460, maxHeight), math.min(245, maxHeight), maxHeight)
            state.x = math.clamp(state.x or math.floor((vw - state.width) * 0.5), 10, math.max(10, vw - state.width - 10))
            state.y = math.clamp(state.y or 24, 10, math.max(10, vh - state.height - 10))
            setRect(state.panel, state.x, state.y, state.width, state.height)
            local w, h = state.width, state.height
            local short, tiny = h < 300, h < 210
            setRect(state.header, 0, 0, w, 34)
            setRect(state.dragHandle, 0, 0, w - 52, 34)
            setRect(state.brand, 12, 0, w - 78, 34)
            setRect(state.hideButton, w - 42, 6, 30, 23)
            state.sessionLabel.Visible, state.resultLabel.Visible = not short, not short
            state.navPrevious.Visible, state.navNext.Visible = not tiny, not tiny
            state.attemptLabel.Visible, state.followButton.Visible = not tiny, not tiny
            setRect(state.sessionLabel, 12, 39, w - 24, 20)
            local actionY = short and 40 or 64
            local actionScale = math.min(1, math.max(0.1, (w - 36) / 264))
            setRect(state.copyButton, 12, actionY, 114 * actionScale, 28)
            setRect(state.saveButton, 18 + 114 * actionScale, actionY, 66 * actionScale, 28)
            setRect(state.clearButton, 24 + 180 * actionScale, actionY, 72 * actionScale, 28)
            state.copyButton.Text = w < 300 and "COPIAR" or "COPIAR TUDO"
            state.copyButton.TextSize = w < 300 and 10 or 12
            state.clearButton.TextSize = w < 300 and 10 or 12
            local navY = short and 76 or 100
            setRect(state.navPrevious, 12, navY, 28, 25)
            setRect(state.navNext, 44, navY, 28, 25)
            setRect(state.attemptLabel, 80, navY, w - 161, 25)
            setRect(state.followButton, w - 73, navY, 61, 25)
            local tabWidth = math.min(98, (w - 24) / 3)
            local tabY = tiny and 76 or short and 110 or 134
            setRect(state.tabs.summary, 12, tabY, tabWidth, 27)
            setRect(state.tabs.events, 12 + tabWidth, tabY, tabWidth, 27)
            setRect(state.tabs.raw, 12 + tabWidth * 2, tabY, tabWidth, 27)
            state.detailButton.Visible = w >= 480
            setRect(state.detailButton, w - 126, tabY + 1, 114, 25)
            setRect(state.resultLabel, 12, 166, w - 24, 20)
            local codeY = tiny and 110 or short and 144 or 192
            local narrow = w < 520
            local footerHeight = narrow and 53 or 34
            local codeHeight = math.max(0, h - codeY - footerHeight)
            state.codeWidth, state.codeHeight = math.max(1, w - 32), codeHeight
            setRect(state.scroll, 12, codeY, w - 24, codeHeight)
            setRect(state.statusLabel, 12, h - 26, narrow and (w - 36) or (w - 182), 18)
            local pageY = h - (narrow and 49 or 28)
            setRect(state.pagePrevious, w - 164, pageY, 24, 19)
            setRect(state.pageLabel, w - 138, pageY, 96, 19)
            setRect(state.pageNext, w - 40, pageY, 24, 19)
            setRect(state.resizeHandle, w - 15, h - 12, 14, 11)
            setRect(state.toggle, math.max(8, vw - 122), math.min(58, math.max(8, vh - 40)), 110, 28)
            state.renderedText = nil
            requestRefresh()
        end
        state.layout = layout
        local function clearHistory()
            table.clear(history.lines)
            state.records, state.attempts, state.order = {}, {}, {}
            history.startedAt, history.attempts = os.clock(), 0
            history.clears += 1
            state.startedAt, state.attempt, state.selected, state.page = history.startedAt, 0, 0, 1
            state.legacyNotice = nil
            state.log("DIAG", "Histórico limpo explicitamente; aguardando eventos")
            state.persist()
            status("Histórico limpo por você.")
            requestRefresh()
        end
        local function createGui()
            stopGui()
            state.gui = Instance.new("ScreenGui")
            state.gui.Name, state.gui.ResetOnSpawn, state.gui.IgnoreGuiInset = "__Standalone_BombJump_Firefly_Diagnostics", false, true
            state.gui.DisplayOrder, state.gui.ZIndexBehavior = 1000001, Enum.ZIndexBehavior.Sibling
            local parentOk = pcall(function() state.gui.Parent = CoreGui end)
            if not parentOk or not state.gui.Parent then
                local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 3)
                if playerGui then state.gui.Parent = playerGui end
            end
            if not state.gui.Parent then error("Nenhum contêiner de interface disponível") end
            state.panel = ui("Frame", "Panel", state.gui, {BackgroundColor3 = colors.window,
                BorderSizePixel = 0, ClipsDescendants = true, Active = true})
            ui("UICorner", "Corner", state.panel, {CornerRadius = UDim.new(0, 7)})
            ui("UIStroke", "Border", state.panel, {Color = colors.border, Thickness = 1})
            state.header = ui("Frame", "Header", state.panel, {BackgroundColor3 = colors.header, BorderSizePixel = 0})
            state.dragHandle = ui("Frame", "DragHandle", state.header, {BackgroundTransparency = 1, Active = true})
            state.brand = label("Brand", state.dragHandle, "<> FIREFLY / DEBUGGER", 13, colors.accent)
            state.brand.Active = true
            state.hideButton = button("Hide", state.header, "_", function()
                state.panel.Visible, state.toggle.Visible, state.drag = false, true, nil
            end)
            state.sessionLabel = label("Session", state.panel, "", 11, colors.muted)
            state.copyButton = button("Copy", state.panel, "COPIAR TUDO", function()
                local content, ok = state.export(), false
                if type(setclipboard) == "function" then ok = pcall(setclipboard, content)
                elseif type(toclipboard) == "function" then ok = pcall(toclipboard, content) end
                local saved = state.persist()
                status(ok and ("Histórico completo copiado: " .. #history.lines .. " registros.")
                    or saved and ("Completo salvo em " .. state.fileName)
                    or "Clipboard/arquivo indisponíveis; histórico mantido nesta sessão.")
            end)
            state.saveButton = button("Save", state.panel, ".TXT", function()
                status(state.persist() and ("Salvo: " .. state.fileName) or "Arquivo indisponível; use COPIAR TUDO.")
            end)
            state.clearButton = button("Clear", state.panel, "LIMPAR", clearHistory)
            local function select(delta)
                local index = table.find(state.order, state.selected) or #state.order
                state.selected = state.order[math.clamp(index + delta, 1, math.max(1, #state.order))] or 0
                state.follow, state.page = false, 1
                requestRefresh()
            end
            state.navPrevious = button("PreviousAttempt", state.panel, "<", function() select(-1) end)
            state.navNext = button("NextAttempt", state.panel, ">", function() select(1) end)
            state.attemptLabel = label("Attempt", state.panel, "", 12)
            state.followButton = button("Latest", state.panel, "ÚLTIMA", function()
                state.follow, state.selected, state.page = true, state.order[#state.order] or 0, 1
                requestRefresh()
            end)
            state.tabs = {}
            for _, tab in ipairs({{"summary", "RESUMO"}, {"events", "EVENTOS"}, {"raw", "BRUTO"}}) do
                local key = tab[1]
                state.tabs[key] = button("Tab_" .. key, state.panel, tab[2], function()
                    state.view, state.page = key, 1
                    requestRefresh()
                end)
            end
            state.detailButton = button("Details", state.panel, "DETALHES OFF", function()
                state.detailed, state.page = not state.detailed, 1
                requestRefresh()
            end)
            state.resultLabel = label("Result", state.panel, "", 12, colors.blue)
            state.scroll = ui("ScrollingFrame", "LogScroll", state.panel, {BackgroundColor3 = Color3.fromRGB(9, 13, 18),
                BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.XY,
                CanvasSize = UDim2.fromOffset(0, 0), ClipsDescendants = true, Active = true})
            state.textLabel = ui("TextBox", "LogText", state.scroll, {Position = UDim2.fromOffset(8, 7),
                BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.Code, TextSize = 12,
                TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false, MultiLine = true,
                TextEditable = false, ClearTextOnFocus = false, Text = "", RichText = false})
            state.statusLabel = label("Status", state.panel, state.notice or (state.legacyNotice
                and "Importação: início do histórico antigo incompleto." or "Captura completa ativa."), 10, colors.muted)
            state.pagePrevious = button("PreviousPage", state.panel, "<", function()
                state.page = math.max(1, state.page - 1); requestRefresh()
            end)
            state.pageLabel = label("Page", state.panel, "", 10, colors.muted)
            state.pageLabel.TextXAlignment = Enum.TextXAlignment.Center
            state.pageNext = button("NextPage", state.panel, ">", function()
                state.page = math.min(state.pageCount or 1, state.page + 1); requestRefresh()
            end)
            state.resizeHandle = button("Resize", state.panel, "/", function() end)
            state.resizeHandle.BackgroundTransparency = 1
            state.resizeHandle.TextColor3 = colors.muted
            state.toggle = button("ShowDiagnostics", state.gui, "JAR DEBUG", function()
                state.panel.Visible, state.toggle.Visible = true, false
                layout(); requestRefresh()
            end)
            state.toggle.Visible = false
            state.panel.Visible = true
            local function startDrag(input, mode)
                if state.drag or (input.UserInputType ~= Enum.UserInputType.Touch
                    and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
                state.drag = {input = input, mode = mode, start = input.Position,
                    x = state.x, y = state.y, width = state.width, height = state.height}
            end
            connect(state.dragHandle.InputBegan, function(input) startDrag(input, "move") end)
            connect(state.brand.InputBegan, function(input) startDrag(input, "move") end)
            connect(state.resizeHandle.InputBegan, function(input) startDrag(input, "resize") end)
            connect(UIS.InputChanged, function(input)
                local drag = state.drag
                if not drag then return end
                local touch = drag.input.UserInputType == Enum.UserInputType.Touch
                if (touch and input ~= drag.input) or (not touch and input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
                local delta = input.Position - drag.start
                if drag.mode == "move" then state.x, state.y = drag.x + delta.X, drag.y + delta.Y
                else state.width, state.height = drag.width + delta.X, drag.height + delta.Y end
                layout()
            end)
            connect(UIS.InputEnded, function(input)
                local drag = state.drag
                if drag and (input == drag.input or (drag.input.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseButton1)) then state.drag = nil end
            end)
            pcall(function() connect(UIS.WindowFocusReleased, function() state.drag = nil end) end)
            pcall(function() connect(state.gui:GetPropertyChangedSignal("AbsoluteSize"), layout) end)
            layout()
        end
        state.beginAttempt = function()
            history.attempts += 1
            state.attempt = history.attempts
            if state.follow then state.selected, state.page = state.attempt, 1 end
        end
        state.log = function(tag, detail)
            local name = tostring(tag)
            if state.stopped or not state.enabled or name:sub(1, 5) == "BOMB_" or name:sub(1, 7) == "NORMAL_"
                or name:sub(1, 8) == "BLATANT_" or name == "THROW" or name == "HAND" or name == "FLOOR"
                or name == "JUMP_SETTINGS" or name == "NO_BOMB_OBSERVED" then return end
            local line = string.format("+%.3fs | %s | attempt=%d%s", os.clock() - state.startedAt, name, state.attempt or 0,
                detail ~= nil and ("; " .. tostring(detail)) or "")
            history.lines[#history.lines + 1] = line
            ingest(line, state.attempt)
            requestRefresh()
            if (name == "ATTEMPT_FINISH" or name == "PLAYER_UNLOCK_DONE" or name == "ACTIVATION_FAILED"
                or name == "ACTIVATION_ERROR") and not state.persistQueued then
                state.persistQueued = true
                task.defer(function() state.persistQueued = false; state.persist() end)
            end
        end
        state.setEnabled = function(value)
            state.enabled = value == true
            if state.enabled and not state.gui then
                local ok, err = pcall(createGui)
                if not ok then
                    stopGui()
                    state.guiError = tostring(err)
                    warn("[Firefly diagnostic UI] " .. tostring(err))
                end
            end
            if state.gui then state.gui.Enabled = state.enabled end
            if state.enabled and not state.runAnnounced then
                state.runAnnounced = true
                state.log("DIAG_SESSION", string.format("build=%s; execution=%d; retained=%d; automaticTruncation=false; place=%s; job=%s",
                    state.build, history.runs, #history.lines, tostring(game.PlaceId), tostring(game.JobId)))
            end
            if state.enabled then requestRefresh() end
        end
        sharedEnv.__StandaloneBombJumpFireflyDiagnosticsCleanup = function()
            state.stopped = true
            stopGui()
            task.defer(function() state.persist() end)
        end
    end
    local ok, err = pcall(initialize)
    if not ok then
        state.initError = tostring(err)
        state.log = function() end
        state.beginAttempt = function() end
        state.setEnabled = function() end
        state.persist = function() return false end
        warn("[Firefly diagnostics initialization] " .. tostring(err))
    end
end

local Config = {
    BOMB_AIM_DROP_BASE = 0.025,
    BOMB_AIM_DROP_MAX = 0.040,
    BOMB_BOUNCE_CHECK_RADIUS = 3.5,
    BOMB_BOUNCE_INPUT_HOLD_TIME = 0.25,
    BOMB_BOUNCE_TRACK_TIME = 1.25,
    BOMB_DRAG_THRESHOLD = 8,
    BOMB_EQUIP_TIMEOUT = 0.18,
    BOMB_FORWARD_BIAS = 0.055,
    BOMB_FORWARD_MAX = 0.11,
    BOMB_FORWARD_PING_SCALE = 0.04,
    BOMB_FORWARD_SPEED_SCALE = 0.0018,
    BOMB_GROUND_SINK = 0.08,
    BOMB_HIGH_PING_FORWARD_MAX = 2.00,
    BOMB_HIGH_PING_FORWARD_MIN = 0.35,
    BOMB_HIGH_PING_FORWARD_SCALE = 4.0,
    BOMB_HIGH_PING_THRESHOLD = 0.10,
    BOMB_LAUNCH_FALL_SPEED = 1.0,
    BOMB_MAX_HORIZONTAL_PREDICTION = 0.18,
    BOMB_MAX_SURFACE_RISE = 0.30,
    BOMB_PREDICTION_INPUT_BASE = 0.008,
    BOMB_PREDICTION_INPUT_MAX = 0.020,
    BOMB_PREDICTION_ITERATIONS = 1,
    BOMB_PREDICTION_PING_SCALE = 0.12,
    BOMB_TARGET_CLEARANCE = 0.04,
    BOMB_TARGET_RAY_HEIGHT = 12,
    BOMB_TARGET_RAY_LENGTH = 120,
    BOMB_FREEFALL_GROUND_RAY_MARGIN = 0.10,
    FIREFLY_ARM_INITIAL_TRAVEL_RATIO = 0.025,
    FIREFLY_ARM_REVERSAL_FRAMES = 2,
    FIREFLY_ARM_SECOND_TRAVEL_RATIO = 0.010,
    FIREFLY_ARM_TRACK_TIMEOUT = 4.0,
    FIREFLY_COOLDOWN = 10.0,
    FIREFLY_COOLDOWN_START_DELAY = 6.0,
    FIREFLY_EQUIP_SETTLE_TIME = 0.12,
    FIREFLY_FIRST_JUMP_HOLD_TIME = 0.55,
    FIREFLY_FIRST_JUMP_RETURN_RATIO = 0.15,
    FIREFLY_FORWARD_HOLD_TIME = 0.55,
    FIREFLY_FORWARD_MAX_HOLD_TIME = 1.25,
    FIREFLY_SECOND_JUMP_CONFIRM_TIME = 0.35,
    FIREFLY_LID_APPROACH_CLEARANCE = 0.12,
    FIREFLY_FORWARD_MOVEMENT_BIND_NAME = "__BombJumpFireflyForwardMovement",
    FIREFLY_JUMP_INPUT_LOCK_NAME = "__BombJumpFireflyJumpInputLock",
    FIREFLY_RELEASE_DELAY = 6.0,
    GOLD_COOLDOWN = 3.2,
    GUI_NAME = "__Standalone_BombJump",
    NORMAL_COOLDOWN = 21.7,
    POSITION_FILE = "BombJump_Standalone_Position.json",
}

pcall(function()
    RunService:UnbindFromRenderStep("__FireflyDoubleJumpIdleMovementLock")
    RunService:UnbindFromRenderStep(Config.FIREFLY_FORWARD_MOVEMENT_BIND_NAME)
    local contextActionService = game:GetService("ContextActionService")
    contextActionService:UnbindAction("__FireflyDoubleJumpMovementLock")
    contextActionService:UnbindAction(Config.FIREFLY_JUMP_INPUT_LOCK_NAME)
end)
pcall(function()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid:GetAttribute("__FireflyMovementLockActive") then
        local originalWalkSpeed = humanoid:GetAttribute("__FireflyMovementLockWalkSpeed")
        if typeof(originalWalkSpeed) == "number" then
            humanoid.WalkSpeed = originalWalkSpeed
        end
        humanoid:SetAttribute("__FireflyMovementLockWalkSpeed", nil)
        humanoid:SetAttribute("__FireflyMovementLockActive", nil)
        humanoid.Jump = false
        humanoid:Move(Vector3.zero, false)
    end
end)

pcall(function()
    local old = CoreGui:FindFirstChild(Config.GUI_NAME)
    if old then
        old:Destroy()
    end
end)

local toyEvent
local function resolveToyEvent()
    if toyEvent and toyEvent.Parent then
        return toyEvent
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local remote = extras and extras:FindFirstChild("ReplicateToy")
    toyEvent = remote and remote:IsA("RemoteFunction") and remote or nil
    return toyEvent
end

resolveToyEvent()

local savedPositions = {}
local GuiPositionRecovery = {}
pcall(function()
    if type(readfile) == "function" and type(isfile) == "function" and isfile(Config.POSITION_FILE) then
        local decoded = HttpService:JSONDecode(readfile(Config.POSITION_FILE))
        if type(decoded) == "table" then
            savedPositions = decoded
        end
    end
end)

GuiPositionRecovery.readUDim2 = function(value)
    if type(value) ~= "table" then
        return nil
    end
    local xs, xo, ys, yo = tonumber(value[1]), tonumber(value[2]), tonumber(value[3]), tonumber(value[4])
    if not xs or not xo or not ys or not yo then
        return nil
    end
    return UDim2.new(xs, xo, ys, yo)
end

GuiPositionRecovery.savePositions = function()
    pcall(function()
        if type(writefile) ~= "function" then
            return
        end
        writefile(Config.POSITION_FILE, HttpService:JSONEncode(savedPositions))
    end)
end


GuiPositionRecovery.resolve = function(key, defaultPosition, width, height)
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize
    if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
        return defaultPosition
    end

    local storedPosition = GuiPositionRecovery.readUDim2(savedPositions[key])

    local function isFullyVisible(position)
        if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
            return false
        end

        local x = position.X.Scale * viewport.X + position.X.Offset
        local y = position.Y.Scale * viewport.Y + position.Y.Offset
        return x >= 0
            and y >= 0
            and x + width <= viewport.X
            and y + height <= viewport.Y
    end

    if storedPosition and isFullyVisible(storedPosition) then
        return storedPosition
    end

    local fallbackPosition = defaultPosition
    if viewport and viewport.X > 0 and viewport.Y > 0 and not isFullyVisible(fallbackPosition) then
        local defaultX = fallbackPosition.X.Scale * viewport.X + fallbackPosition.X.Offset
        local defaultY = fallbackPosition.Y.Scale * viewport.Y + fallbackPosition.Y.Offset
        local maxX = math.max(0, viewport.X - width)
        local maxY = math.max(0, viewport.Y - height)
        fallbackPosition = UDim2.fromOffset(
            math.floor(math.clamp(defaultX, 0, maxX)),
            math.floor(math.clamp(defaultY, 0, maxY))
        )
    end

    if storedPosition then
        savedPositions[key] = {
            fallbackPosition.X.Scale,
            fallbackPosition.X.Offset,
            fallbackPosition.Y.Scale,
            fallbackPosition.Y.Offset,
        }
        GuiPositionRecovery.savePositions()
    end

    return fallbackPosition
end

GuiPositionRecovery.clampNumber = function(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local savedBombSettings = type(savedPositions.BombSettings) == "table" and savedPositions.BombSettings or {}

local function savedBoolean(key, defaultValue)
    if type(savedBombSettings[key]) == "boolean" then
        return savedBombSettings[key]
    end
    return defaultValue
end

local function savedNumber(key, defaultValue)
    local value = tonumber(savedBombSettings[key])
    return value or defaultValue
end

local function savedString(key, defaultValue)
    return type(savedBombSettings[key]) == "string" and savedBombSettings[key] or defaultValue
end

if savedBombSettings.BombStyle ~= "Legit"
    and savedBombSettings.BombStyle ~= "Blatant" then
    savedBombSettings.BombStyle = "Legit"
end

local currentColor = Color3.fromRGB(255, 255, 255)
local colorPresets = {
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(170, 210, 255),
    Color3.fromRGB(180, 120, 255),
    Color3.fromRGB(255, 100, 170),
    Color3.fromRGB(80, 255, 190),
    Color3.fromRGB(255, 190, 70),
}
local colorIndex = GuiPositionRecovery.clampNumber(math.floor(savedNumber("ColorIndex", 1)), 1, 6)
local savedColor = savedBombSettings.Color
if type(savedColor) == "table" then
    local r = tonumber(savedColor[1])
    local g = tonumber(savedColor[2])
    local b = tonumber(savedColor[3])
    if r and g and b then
        currentColor = Color3.new(
            GuiPositionRecovery.clampNumber(r, 0, 1),
            GuiPositionRecovery.clampNumber(g, 0, 1),
            GuiPositionRecovery.clampNumber(b, 0, 1)
        )
    else
        currentColor = colorPresets[colorIndex]
    end
else
    currentColor = colorPresets[colorIndex]
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = Config.GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

local menu = Instance.new("Frame")
menu.Name = "Settings"
menu.Size = UDim2.fromOffset(290, 340)
menu.Position = GuiPositionRecovery.resolve("Menu", UDim2.new(0.5, -145, 0.5, -175), 290, 340)
menu.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
menu.BorderSizePixel = 0
menu.Parent = screenGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 14)
menuCorner.Parent = menu

local menuStroke = Instance.new("UIStroke")
menuStroke.Thickness = 2
menuStroke.Color = currentColor
menuStroke.Transparency = 0.15
menuStroke.Parent = menu

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 54)
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.Parent = menu

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "BOMB JUMP"
title.TextColor3 = Color3.fromRGB(245, 245, 250)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -58, 0, 18)
subtitle.Position = UDim2.fromOffset(10, 31)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Standalone controller"
subtitle.TextColor3 = Color3.fromRGB(145, 150, 165)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = titleBar

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -20, 1, -68)
content.Position = UDim2.fromOffset(10, 60)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.ScrollBarThickness = 3
content.ScrollBarImageTransparency = 0.25
content.Active = true
content.ClipsDescendants = true
content.BackgroundTransparency = 1
content.Parent = menu

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local function makeRow(height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height or 42)
    row.BackgroundColor3 = Color3.fromRGB(27, 30, 38)
    row.BorderSizePixel = 0
    row.Parent = content
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = row
    return row
end

local function makeLabel(row, textValue)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.56, -8, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.Text = textValue
    label.TextColor3 = Color3.fromRGB(220, 223, 232)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    return label
end

local function makeButton(row, initialText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.42, -8, 0, 30)
    btn.Position = UDim2.new(0.58, 0, 0.5, -15)
    btn.BackgroundColor3 = Color3.fromRGB(38, 42, 53)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Font = Enum.Font.GothamBold
    btn.Text = initialText
    btn.TextColor3 = Color3.fromRGB(235, 238, 245)
    btn.TextSize = 11
    btn.Parent = row
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    return btn
end

local bombUseMode, selectedBombType

do
    local typeSettingsMap = type(savedBombSettings.BombTypeSettings) == "table"
        and savedBombSettings.BombTypeSettings
        or {}
    local legacyMode = savedString("BombUseMode", "Click To Use Bomb")
    local legacyStyle = savedBombSettings.BombStyle

    if legacyMode ~= "Toggle To Use Bomb" and legacyMode ~= "Click To Use Bomb" and legacyMode ~= "Armed To Use Bomb" then
        legacyMode = "Click To Use Bomb"
    end
    if legacyStyle ~= "Legit" and legacyStyle ~= "Blatant" then
        legacyStyle = "Legit"
    end

    selectedBombType = savedString("BombType", "Bomb")
    if selectedBombType ~= "Bomb" and selectedBombType ~= "Gold Bomb" and selectedBombType ~= "Firefly Jar" then
        selectedBombType = "Bomb"
    end

    savedBombSettings.BombTypeSettings = typeSettingsMap
    for _, typeName in ipairs({"Bomb", "Gold Bomb", "Firefly Jar"}) do
        local typeSettings = typeSettingsMap[typeName]
        if type(typeSettings) ~= "table" then
            typeSettings = {}
            typeSettingsMap[typeName] = typeSettings
        end

        if typeSettings.UsageMode ~= "Toggle To Use Bomb"
            and typeSettings.UsageMode ~= "Click To Use Bomb"
            and typeSettings.UsageMode ~= "Armed To Use Bomb" then
            typeSettings.UsageMode = typeName == selectedBombType and legacyMode or "Click To Use Bomb"
        end

        if typeSettings.Style ~= "Legit"
            and typeSettings.Style ~= "Blatant" then
            typeSettings.Style = typeName == selectedBombType and legacyStyle or "Legit"
        end

        if typeName == "Firefly Jar" then
            typeSettings.UsageMode = "Click To Use Bomb"
        end
    end

    local activeTypeSettings = typeSettingsMap[selectedBombType]
    bombUseMode = activeTypeSettings.UsageMode
    savedBombSettings.BombStyle = activeTypeSettings.Style
end
fireflyDiag.setEnabled(selectedBombType == "Firefly Jar")
local noGuiTimerBomb = savedBoolean("HideGuiTimer", false)
local showBombJumpGui = savedBoolean("ShowBombJumpButton", false)
local lockBombPosition = savedBoolean("LockBombPosition", false)
local bombJumpGuiSize = GuiPositionRecovery.clampNumber(savedNumber("ButtonSize", 110), 50, 300)
local menuCollapsed = savedBoolean("MenuCollapsed", false)
local isActiveBomb = savedBoolean("IsActive", false) and bombUseMode == "Toggle To Use Bomb"
local isArmedBomb = false
local lastKnownBombTool = nil
local hasTriggeredBomb = false
local isWaitingTimerBomb = false

local bombFrame
local bombButton
local bombStroke
local cooldownOverlay
local draggingBomb = false
local dragInputBomb
local dragStartBomb
local startPosBomb
local movedBomb = false
local dragTouchBomb
local bombActionInProgress = false
local pendingBombJump = false
local pendingBombTool = nil
local pendingBombCharacter = nil
local pendingBombHumanoid = nil
local pendingBombRootPart = nil
local pendingBombWasEquipped = false
local pendingBombManualActivationOriginal = nil
local pendingBombStateConnection = nil
local pendingBombHeartbeatConnection = nil
local pendingBombWasToggle = false
local pendingBombEquipDeadline = 0
local pendingBombLaunchWindowReached = false
local pendingBombLaunchWaitDeadline = nil
local pendingBombStartedInFreefall = false
local pendingBombLaunchInProgress = false
local pendingBombSequenceGeneration = 0
local fireflyTimingChildConnection = nil
local fireflyTimingRenderConnection = nil
local fireflyTimingActive = false
local fireflyTimingStartedAt = 0
local fireflyTimingElapsed = nil
local fireflyDoubleJumpRenderConnection = nil
local fireflyDoubleJumpStateConnection = nil
local fireflyDoubleJumpJumpingConnection = nil
local fireflyDoubleJumpPhysicsConnection = nil
local fireflyDoubleJumpLidConnection = nil
local fireflyDoubleJumpForwardConnection = nil
local fireflyDoubleJumpJumpConnection = nil
local fireflySecondJumpClearConnection = nil
local fireflyDoubleJumpLid = nil
local fireflyFirstJumpTriggered = false
local bombCooldownGeneration = 0
local resetBombCooldown
local cancelFireflyDoubleJump
local cancelPendingBombJump
local bombPressInput = nil
local bombPressReleased = false
local bombPressWasDragged = false
local bombToolActivationLocked = false
local bombToolActivationOriginal = nil
local bombToolActivationReference = nil
local preEquippedBombTool = nil
local preEquippedBombWasEquipped = false
local preEquippedBombAt = 0
local preEquipBombGeneration = 0

local function findSelectedBombTool(container)
    if not container then
        return nil
    end

    local preferredName
    if selectedBombType == "Gold Bomb" then
        preferredName = "GoldBomb"
    elseif selectedBombType == "Firefly Jar" then
        preferredName = "Fireflies"
    else
        preferredName = "FakeBomb"
    end

    if selectedBombType == "Firefly Jar" then
        local exact = container:FindFirstChild("Fireflies")
        if exact and exact:IsA("Tool") then
            return exact
        end

        local toys = container:FindFirstChild("Toys")
        local fireflies = toys and toys:FindFirstChild("Fireflies")
        if fireflies and fireflies:IsA("Tool") then
            return fireflies
        end

        return nil
    end

    local exact = container:FindFirstChild(preferredName)
    if exact and exact:IsA("Tool") then
        return exact
    end

    return nil
end

local function findRealFireflyJar(player)
    if not player then
        return nil
    end

    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    if character then
        local fireflies = character:FindFirstChild("Fireflies")
        if fireflies and fireflies:IsA("Tool") then
            return fireflies
        end
    end

    if backpack then
        local fireflies = backpack:FindFirstChild("Fireflies")
        if fireflies and fireflies:IsA("Tool") then
            return fireflies
        end
    end

    return nil
end

local function prepareRealFireflyJar(player)
    if not player then
        return nil
    end

    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    if not backpack then
        return nil
    end

    local fireflies = findRealFireflyJar(player)
    if fireflies then
        return fireflies
    end

    local toys = backpack:FindFirstChild("Toys")
    local toyFireflies = toys and toys:FindFirstChild("Fireflies")
    if not toyFireflies or not toyFireflies:IsA("Tool") then
        return nil
    end

    local remote = resolveToyEvent()
    if not remote then
        return nil
    end

    pcall(function()
        remote:InvokeServer("Fireflies")
    end)

    local deadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 0.50)
    while os.clock() < deadline do
        fireflies = findRealFireflyJar(player)
        if fireflies then
            return fireflies
        end
        RunService.Heartbeat:Wait()
    end

    return findRealFireflyJar(player)
end


local function clearPreEquippedBomb()
    preEquipBombGeneration = preEquipBombGeneration + 1
    preEquippedBombTool = nil
    preEquippedBombWasEquipped = false
    preEquippedBombAt = 0
end

local function requestFastBombEquip(humanoid, character, bombTool)
    if not humanoid or not character or not bombTool then
        return
    end

    if bombTool.Parent == character then
        lastKnownBombTool = bombTool
    elseif bombTool.Parent == LocalPlayer:FindFirstChild("Backpack") then
        lastKnownBombTool = bombTool
    end

    preEquipBombGeneration = preEquipBombGeneration + 1
    local generation = preEquipBombGeneration

    pcall(function()
        humanoid:EquipTool(bombTool)
    end)

    if bombTool.Parent ~= character then
        pcall(function()
            bombTool.Parent = character
        end)
    end

    if bombTool.Parent == character then
        preEquippedBombAt = os.clock()
    end

    task.spawn(function()
        local deadline = os.clock() + 2.50
        while preEquipBombGeneration == generation
            and bombTool.Parent ~= character
            and os.clock() < deadline do
            pcall(function()
                humanoid:EquipTool(bombTool)
            end)
            if bombTool.Parent ~= character then
                pcall(function()
                    bombTool.Parent = character
                end)
            end
            if bombTool.Parent == character and preEquippedBombAt == 0 then
                preEquippedBombAt = os.clock()
            end
            RunService.Heartbeat:Wait()
        end
    end)
end

local function releaseScriptEquippedBomb(bombTool, character, humanoid, wasPreviouslyEquipped)
    if wasPreviouslyEquipped or not bombTool or not character or not humanoid then
        return
    end

    task.spawn(function()
        pcall(function()
            if bombTool.Parent == character then
                humanoid:UnequipTools()
            end
        end)

        RunService.Heartbeat:Wait()

        pcall(function()
            if bombTool.Parent == character then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    bombTool.Parent = backpack
                end
            end
        end)
    end)
end
local lockBombActivation
local unlockBombActivation
local saveBombSettings
local renderBombVisualState
local isBombJumpGrounded

local function getBombTextSize()
    return math.clamp(math.floor(bombJumpGuiSize / 8), 12, 32)
end

local function updateBombVisuals()
    if not bombButton or not bombStroke then
        return
    end
    bombButton.TextSize = getBombTextSize()
    bombFrame.Size = UDim2.new(0, bombJumpGuiSize, 0, bombJumpGuiSize * (100 / 220))
    if not isWaitingTimerBomb
        and not (pendingBombJump and bombUseMode == "Armed To Use Bomb" and not pendingBombWasToggle)
        and not (bombUseMode == "Armed To Use Bomb" and isArmedBomb)
        and not (bombUseMode == "Toggle To Use Bomb" and isActiveBomb) then
        bombStroke.Color = currentColor
    end
end

local defaultBombPos = UDim2.new(1, -240, 1, -210)

local bombGui = Instance.new("ScreenGui")
bombGui.Name = "BombJumpButtonGui"
bombGui.ResetOnSpawn = false
bombGui.IgnoreGuiInset = true
bombGui.DisplayOrder = 1000000
bombGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bombGui.Enabled = false
bombGui.Parent = CoreGui

bombFrame = Instance.new("Frame")
bombFrame.Name = "BombFrame"
bombFrame.Size = UDim2.new(0, bombJumpGuiSize, 0, bombJumpGuiSize * (100 / 220))
bombFrame.Position = GuiPositionRecovery.resolve(
    "BombButton",
    defaultBombPos,
    bombJumpGuiSize,
    bombJumpGuiSize * (100 / 220)
)
bombFrame.BackgroundTransparency = 1
bombFrame.Parent = bombGui

local bombCorner = Instance.new("UICorner")
bombCorner.CornerRadius = UDim.new(0, 4)
bombCorner.Parent = bombFrame

bombStroke = Instance.new("UIStroke")
bombStroke.Color = currentColor
bombStroke.Thickness = 3.5
bombStroke.Parent = bombFrame

bombButton = Instance.new("TextButton")
bombButton.Size = UDim2.fromScale(1, 1)
bombButton.BackgroundTransparency = 1
bombButton.Text = selectedBombType == "Firefly Jar"
    and "Jar jump"
    or (bombUseMode == "Toggle To Use Bomb" and (isActiveBomb and "Ready" or "Bomb Jump (OFF)") or "Bomb Jump")
bombButton.TextColor3 = Color3.fromRGB(255, 255, 255)
bombButton.TextSize = getBombTextSize()
bombButton.TextXAlignment = Enum.TextXAlignment.Center
bombButton.TextYAlignment = Enum.TextYAlignment.Center
bombButton.TextWrapped = true
bombButton.Font = Enum.Font.GothamBold
bombButton.ZIndex = 2
bombButton.Parent = bombFrame

cooldownOverlay = Instance.new("Frame")
cooldownOverlay.Name = "CooldownOverlay"
cooldownOverlay.Position = UDim2.fromOffset(-4, -4)
cooldownOverlay.Size = UDim2.new(1, 8, 1, 8)
cooldownOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
cooldownOverlay.BackgroundTransparency = 1
cooldownOverlay.BorderSizePixel = 0
cooldownOverlay.Active = false
cooldownOverlay.ZIndex = 100
cooldownOverlay.Parent = bombButton

local cooldownCorner = Instance.new("UICorner")
cooldownCorner.CornerRadius = UDim.new(0, 8)
cooldownCorner.Parent = cooldownOverlay

bombGui.Enabled = showBombJumpGui

local function saveBombButtonPosition()
    savedPositions.BombButton = {
        bombFrame.Position.X.Scale,
        bombFrame.Position.X.Offset,
        bombFrame.Position.Y.Scale,
        bombFrame.Position.Y.Offset,
    }
    GuiPositionRecovery.savePositions()
end

saveBombSettings = function()
    local typeSettingsMap = savedBombSettings.BombTypeSettings
    if type(typeSettingsMap) == "table" then
        local currentTypeSettings = typeSettingsMap[selectedBombType]
        if type(currentTypeSettings) == "table" then
            currentTypeSettings.UsageMode = selectedBombType == "Firefly Jar"
                and "Click To Use Bomb"
                or bombUseMode
            currentTypeSettings.Style = savedBombSettings.BombStyle or currentTypeSettings.Style or "Legit"
        end
    end

    savedPositions.BombSettings = {
        BombUseMode = bombUseMode,
        BombType = selectedBombType,
        BombStyle = savedBombSettings.BombStyle or "Legit",
        BombTypeSettings = typeSettingsMap,
        HideGuiTimer = noGuiTimerBomb,
        ShowBombJumpButton = showBombJumpGui,
        LockBombPosition = lockBombPosition,
        ButtonSize = bombJumpGuiSize,
        MenuCollapsed = menuCollapsed,
        IsActive = isActiveBomb,
        ColorIndex = colorIndex,
        Color = {currentColor.R, currentColor.G, currentColor.B},
    }
    GuiPositionRecovery.savePositions()
end

bombButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    draggingBomb = false
    dragTouchBomb = input
    movedBomb = false
    bombPressInput = input
    bombPressReleased = false
    bombPressWasDragged = false
    lockBombActivation()

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local grounded = character and humanoid and rootPart and isBombJumpGrounded(character, humanoid, rootPart)
    local shouldPreEquip = not isWaitingTimerBomb and selectedBombType ~= "Firefly Jar" and (
        (bombUseMode == "Toggle To Use Bomb" and not isActiveBomb)
        or (bombUseMode == "Armed To Use Bomb" and grounded == true)
        or bombUseMode == "Click To Use Bomb"
    )

    if shouldPreEquip then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local bombTool
        if selectedBombType == "Firefly Jar" then
            bombTool = prepareRealFireflyJar(LocalPlayer)
        else
            bombTool = bombToolActivationReference
                or preEquippedBombTool
                or lastKnownBombTool
                or findSelectedBombTool(character)
                or findSelectedBombTool(backpack)

            if bombTool and bombTool.Parent ~= character and bombTool.Parent ~= backpack then
                bombTool = findSelectedBombTool(character)
                    or findSelectedBombTool(backpack)
            end
        end

        if humanoid and bombTool then
            preEquippedBombTool = bombTool
            preEquippedBombWasEquipped = bombTool.Parent == character
            if not preEquippedBombWasEquipped then
                requestFastBombEquip(humanoid, character, bombTool)
            end
        end
    end

    if not lockBombPosition then
        draggingBomb = true
        dragStartBomb = input.Position
        startPosBomb = bombFrame.Position
    end

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End and dragTouchBomb == input then
            draggingBomb = false
            dragTouchBomb = nil
            dragInputBomb = nil
            bombPressReleased = true
            local wasDragged = bombPressWasDragged
            bombPressInput = nil
            saveBombButtonPosition()
            if wasDragged then
                clearPreEquippedBomb()
            end
            if wasDragged or not pendingBombJump then
                unlockBombActivation()
            end
        end
    end)
end)

bombButton.InputChanged:Connect(function(input)
    if lockBombPosition then
        return
    end
    if dragTouchBomb and input ~= dragTouchBomb then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInputBomb = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if lockBombPosition or not draggingBomb then
        return
    end
    if dragTouchBomb and input.UserInputType == Enum.UserInputType.Touch and input ~= dragTouchBomb then
        return
    end
    if input ~= dragInputBomb and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStartBomb
    if math.abs(delta.X) > Config.BOMB_DRAG_THRESHOLD or math.abs(delta.Y) > Config.BOMB_DRAG_THRESHOLD then
        movedBomb = true
        bombPressWasDragged = true

        if preEquippedBombTool and not preEquippedBombWasEquipped then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and preEquippedBombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
        end

        clearPreEquippedBomb()
    end

    bombFrame.Position = UDim2.new(
        startPosBomb.X.Scale,
        startPosBomb.X.Offset + delta.X,
        startPosBomb.Y.Scale,
        startPosBomb.Y.Offset + delta.Y
    )
end)

local function makeToggleRow(textValue, initialValue, callback)
    local row = makeRow(42)
    makeLabel(row, textValue)
    local btn = makeButton(row, initialValue and "ON" or "OFF")
    local function render(value)
        btn.Text = value and "ON" or "OFF"
        btn.TextColor3 = value and Color3.fromRGB(80, 255, 170) or Color3.fromRGB(235, 238, 245)
    end
    btn.Activated:Connect(function()
        initialValue = not initialValue
        render(initialValue)
        callback(initialValue)
    end)
    render(initialValue)
    return btn
end

makeToggleRow("Show Bomb Jump Button", showBombJumpGui, function(value)
    showBombJumpGui = value
    bombGui.Enabled = value
    if value then
        bombFrame.Position = GuiPositionRecovery.resolve(
            "BombButton",
            defaultBombPos,
            bombJumpGuiSize,
            bombJumpGuiSize * (100 / 220)
        )
    else
        cancelPendingBombJump()
        unlockBombActivation()
        isActiveBomb = false
        hasTriggeredBomb = false
    end
    saveBombSettings()
    renderBombVisualState()
end)

local openDropdown = nil

local function closeOpenDropdown()
    if openDropdown then
        openDropdown.Visible = false
        openDropdown = nil
    end
end

local function makeDropdownSelector(labelText, initialText, options, callback)
    local row = makeRow(42)
    makeLabel(row, labelText)
    local button = makeButton(row, initialText)

    local dropdownHeight = 14 + (#options * 36) + (math.max(#options - 1, 0) * 4)
    local dropdown = makeRow(dropdownHeight)
    dropdown.Visible = false
    dropdown.ZIndex = 20
    dropdown.BackgroundColor3 = Color3.fromRGB(24, 27, 35)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 7)
    padding.PaddingBottom = UDim.new(0, 7)
    padding.PaddingLeft = UDim.new(0, 7)
    padding.PaddingRight = UDim.new(0, 7)
    padding.Parent = dropdown

    local dropdownLayout = Instance.new("UIListLayout")
    dropdownLayout.Padding = UDim.new(0, 4)
    dropdownLayout.FillDirection = Enum.FillDirection.Vertical
    dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropdownLayout.Parent = dropdown

    for index, option in ipairs(options) do
        local optionButton = Instance.new("TextButton")
        optionButton.Size = UDim2.new(1, 0, 0, 36)
        optionButton.BackgroundColor3 = Color3.fromRGB(38, 42, 53)
        optionButton.BorderSizePixel = 0
        optionButton.AutoButtonColor = true
        optionButton.Font = Enum.Font.GothamBold
        optionButton.Text = option.text
        optionButton.TextColor3 = Color3.fromRGB(235, 238, 245)
        optionButton.TextSize = 11
        optionButton.LayoutOrder = index
        optionButton.ZIndex = 21
        optionButton.Parent = dropdown

        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 8)
        optionCorner.Parent = optionButton

        optionButton.Activated:Connect(function()
            callback(option.value, option.text)
            button.Text = option.text
            closeOpenDropdown()
        end)
    end

    button.Activated:Connect(function()
        if openDropdown == dropdown then
            closeOpenDropdown()
            return
        end
        closeOpenDropdown()
        dropdown.Visible = true
        openDropdown = dropdown
    end)

    return button, dropdown
end

local typeOptions = {
    {value = "Bomb", text = "Bomb"},
    {value = "Gold Bomb", text = "Gold Bomb"},
    {value = "Firefly Jar", text = "Firefly Jar"},
}

local updateModeOptionsForBombType

makeDropdownSelector("Bomb Type", selectedBombType, typeOptions, function(newType)
    if selectedBombType == newType then
        return
    end

    cancelPendingBombJump()
    if resetBombCooldown then
        resetBombCooldown()
    end

    local typeSettingsMap = savedBombSettings.BombTypeSettings
    if type(typeSettingsMap) ~= "table" then
        typeSettingsMap = {}
        savedBombSettings.BombTypeSettings = typeSettingsMap
    end

    local currentTypeSettings = typeSettingsMap[selectedBombType]
    if type(currentTypeSettings) ~= "table" then
        currentTypeSettings = {}
        typeSettingsMap[selectedBombType] = currentTypeSettings
    end
    currentTypeSettings.UsageMode = selectedBombType == "Firefly Jar"
        and "Click To Use Bomb"
        or bombUseMode
    currentTypeSettings.Style = savedBombSettings.BombStyle or currentTypeSettings.Style or "Legit"

    selectedBombType = newType
    fireflyDiag.setEnabled(selectedBombType == "Firefly Jar")
    local nextTypeSettings = typeSettingsMap[selectedBombType]
    if type(nextTypeSettings) ~= "table" then
        nextTypeSettings = {UsageMode = "Click To Use Bomb", Style = "Legit"}
        typeSettingsMap[selectedBombType] = nextTypeSettings
    end

    bombUseMode = nextTypeSettings.UsageMode
    if bombUseMode ~= "Toggle To Use Bomb" and bombUseMode ~= "Click To Use Bomb" and bombUseMode ~= "Armed To Use Bomb" then
        bombUseMode = "Click To Use Bomb"
        nextTypeSettings.UsageMode = bombUseMode
    end
    if nextTypeSettings.Style ~= "Legit"
        and nextTypeSettings.Style ~= "Blatant" then
        nextTypeSettings.Style = "Legit"
    end
    savedBombSettings.BombStyle = nextTypeSettings.Style

    if selectedBombType == "Firefly Jar" then
        bombUseMode = "Click To Use Bomb"
        nextTypeSettings.UsageMode = bombUseMode
    end

    isActiveBomb = false
    isArmedBomb = false
    lastKnownBombTool = nil
    saveBombSettings()
    hasTriggeredBomb = false
    if bombButton then
        renderBombVisualState()
    end
    if updateModeOptionsForBombType then
        updateModeOptionsForBombType()
    end
    unlockBombActivation()
end)

do
    local styleOptions = {
        {value = "Legit", text = "Legit"},
        {value = "Blatant", text = "Blatant"},
    }

    local styleButton, styleDropdown = makeDropdownSelector(
        "Style",
        savedBombSettings.BombStyle,
        styleOptions,
        function(newStyle)
            if selectedBombType == "Firefly Jar" then
                return
            end
            if newStyle ~= "Legit" and newStyle ~= "Blatant" then
                return
            end
            if savedBombSettings.BombStyle == newStyle then
                return
            end
            savedBombSettings.BombStyle = newStyle
            saveBombSettings()
        end
    )

    styleButton.Parent.Name = "BombStyleRow"
    styleDropdown.Name = "BombStyleDropdown"
    styleDropdown.Visible = false
end

local function getModeButtonText()
    if bombUseMode == "Toggle To Use Bomb" then
        return "Toggle"
    elseif bombUseMode == "Armed To Use Bomb" then
        return "Armed"
    end
    return "Click"
end

local modeOptions = {
    {value = "Click To Use Bomb", text = "Click"},
    {value = "Toggle To Use Bomb", text = "Toggle"},
    {value = "Armed To Use Bomb", text = "Armed"},
}

local function setBombUseMode(newMode)
    if bombUseMode == newMode then
        return
    end

    cancelPendingBombJump()
    clearPreEquippedBomb()
    local cooldownInProgress = isWaitingTimerBomb
    bombUseMode = newMode
    isActiveBomb = false
    isArmedBomb = false
    hasTriggeredBomb = cooldownInProgress
    saveBombSettings()
    renderBombVisualState()
    unlockBombActivation()
end

local modeButton, modeDropdown = makeDropdownSelector("Usage Mode", getModeButtonText(), modeOptions, function(newMode)
    if selectedBombType == "Firefly Jar" and newMode ~= "Click To Use Bomb" then
        return
    end
    setBombUseMode(newMode)
end)

updateModeOptionsForBombType = function()
    local firefly = selectedBombType == "Firefly Jar"
    if firefly then
        bombUseMode = "Click To Use Bomb"
        modeButton.Text = "Click"
        modeDropdown.Size = UDim2.new(1, 0, 0, 50)
    else
        modeDropdown.Size = UDim2.new(1, 0, 0, 130)
        modeButton.Text = getModeButtonText()
    end

    for _, child in ipairs(modeDropdown:GetChildren()) do
        if child:IsA("TextButton") then
            child.Visible = not firefly or child.Text == "Click"
        end
    end

    local styleRow = content:FindFirstChild("BombStyleRow")
    local styleDropdown = content:FindFirstChild("BombStyleDropdown")
    if styleRow then
        styleRow.Visible = not firefly
        local styleButton = styleRow:FindFirstChildWhichIsA("TextButton")
        if styleButton then
            styleButton.Text = savedBombSettings.BombStyle or "Legit"
        end
    end
    if styleDropdown then
        if firefly and openDropdown == styleDropdown then
            closeOpenDropdown()
        end
        styleDropdown.Visible = false
    end
end

updateModeOptionsForBombType()

local colorNames = {"WHITE", "BLUE", "PURPLE", "PINK", "MINT", "GOLD"}
local colorOptions = {}
for index, name in ipairs(colorNames) do
    colorOptions[index] = {
        value = index,
        text = name,
    }
end

makeDropdownSelector("Border Color", colorNames[colorIndex], colorOptions, function(newIndex)
    colorIndex = newIndex
    currentColor = colorPresets[colorIndex]
    menuStroke.Color = currentColor
    renderBombVisualState()
    saveBombSettings()
end)

makeToggleRow("Hide GUI Timer", noGuiTimerBomb, function(value)
    noGuiTimerBomb = value
    saveBombSettings()
end)


makeToggleRow("Lock Bomb Position", lockBombPosition, function(value)
    lockBombPosition = value
    saveBombSettings()
end)

local sizeRow = makeRow(46)
makeLabel(sizeRow, "Bomb Button Size")

local sizeControls = Instance.new("Frame")
sizeControls.Size = UDim2.fromOffset(126, 30)
sizeControls.Position = UDim2.new(1, -126, 0.5, -15)
sizeControls.BackgroundTransparency = 1
sizeControls.BorderSizePixel = 0
sizeControls.Parent = sizeRow

local sizeMinus = makeButton(sizeControls, "-")
sizeMinus.Size = UDim2.fromOffset(34, 30)
sizeMinus.Position = UDim2.fromOffset(0, 0)

local sizeValue = Instance.new("TextLabel")
sizeValue.Size = UDim2.fromOffset(58, 30)
sizeValue.Position = UDim2.fromOffset(34, 0)
sizeValue.AnchorPoint = Vector2.new(0, 0)
sizeValue.BackgroundTransparency = 1
sizeValue.Font = Enum.Font.GothamBold
sizeValue.TextColor3 = Color3.fromRGB(235, 238, 245)
sizeValue.TextSize = 11
sizeValue.TextXAlignment = Enum.TextXAlignment.Center
sizeValue.TextYAlignment = Enum.TextYAlignment.Center
sizeValue.Text = tostring(bombJumpGuiSize)
sizeValue.Parent = sizeControls

local sizePlus = makeButton(sizeControls, "+")
sizePlus.Size = UDim2.fromOffset(34, 30)
sizePlus.Position = UDim2.fromOffset(92, 0)

local function changeBombSize(delta)
    bombJumpGuiSize = GuiPositionRecovery.clampNumber(bombJumpGuiSize + delta, 50, 300)
    sizeValue.Text = tostring(bombJumpGuiSize)
    updateBombVisuals()
    saveBombSettings()
end
sizeMinus.Activated:Connect(function() changeBombSize(-10) end)
sizePlus.Activated:Connect(function() changeBombSize(10) end)

local statusRow = makeRow(48)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 1, -8)
statusLabel.Position = UDim2.fromOffset(10, 4)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Ready"
statusLabel.TextColor3 = Color3.fromRGB(150, 156, 170)
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusRow

renderBombVisualState = function()
    if not bombButton or not bombStroke then
        return
    end

    if isWaitingTimerBomb then
        bombStroke.Color = Color3.fromRGB(255, 0, 0)
        bombButton.TextColor3 = Color3.fromRGB(255, 70, 70)
        bombButton.AutoButtonColor = false
        if cooldownOverlay then
            cooldownOverlay.BackgroundTransparency = 0.70
        end
        return
    end

    if cooldownOverlay then
        cooldownOverlay.BackgroundTransparency = 1
    end
    bombButton.AutoButtonColor = true

    if bombUseMode == "Armed To Use Bomb" and (isArmedBomb or (pendingBombJump and not pendingBombWasToggle)) then
        bombButton.Text = selectedBombType == "Firefly Jar" and "Jar jump [ARMED]" or "Bomb Jump [ARMED]"
        bombButton.TextColor3 = Color3.fromRGB(255, 220, 80)
        bombStroke.Color = Color3.fromRGB(255, 200, 60)
        return
    end

    if bombUseMode == "Toggle To Use Bomb" and isActiveBomb then
        bombButton.Text = "Ready"
        bombButton.TextColor3 = Color3.fromRGB(50, 255, 50)
        bombStroke.Color = Color3.fromRGB(50, 200, 50)
        return
    end

    bombButton.Text = selectedBombType == "Firefly Jar"
        and "Jar jump"
        or (bombUseMode == "Toggle To Use Bomb" and "Bomb Jump (OFF)" or "Bomb Jump")
    bombButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    bombStroke.Color = currentColor
end

bombGui.Enabled = showBombJumpGui
renderBombVisualState()

local menuDragging = false
local menuDragInput
local menuDragStart
local menuStartPos
local menuTouch

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    menuDragging = true
    menuTouch = input
    menuDragStart = input.Position
    menuStartPos = menu.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End and menuTouch == input then
            menuDragging = false
            menuTouch = nil
            menuDragInput = nil
            savedPositions.Menu = {
                menu.Position.X.Scale,
                menu.Position.X.Offset,
                menu.Position.Y.Scale,
                menu.Position.Y.Offset,
            }
            GuiPositionRecovery.savePositions()
        end
    end)
end)

titleBar.InputChanged:Connect(function(input)
    if menuTouch and input ~= menuTouch then
        return
    end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        menuDragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if not menuDragging then
        return
    end
    if menuTouch and input.UserInputType == Enum.UserInputType.Touch and input ~= menuTouch then
        return
    end
    if input ~= menuDragInput and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local delta = input.Position - menuDragStart
    menu.Position = UDim2.new(
        menuStartPos.X.Scale,
        menuStartPos.X.Offset + delta.X,
        menuStartPos.Y.Scale,
        menuStartPos.Y.Offset + delta.Y
    )
end)

local collapseButton = Instance.new("TextButton")
collapseButton.Size = UDim2.fromOffset(32, 26)
collapseButton.Position = UDim2.new(1, -40, 0, 8)
collapseButton.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
collapseButton.BorderSizePixel = 0
collapseButton.Text = "-"
collapseButton.Font = Enum.Font.GothamBold
collapseButton.TextColor3 = Color3.fromRGB(235, 238, 245)
collapseButton.TextSize = 14
collapseButton.Parent = menu
local collapseCorner = Instance.new("UICorner")
collapseCorner.CornerRadius = UDim.new(0, 8)
collapseCorner.Parent = collapseButton

collapseButton.Activated:Connect(function()
    menuCollapsed = not menuCollapsed
    content.Visible = not menuCollapsed
    menu.Size = menuCollapsed and UDim2.fromOffset(290, 56) or UDim2.fromOffset(290, 340)
    collapseButton.Text = menuCollapsed and "+" or "-"
    saveBombSettings()
end)

content.Visible = not menuCollapsed
menu.Size = menuCollapsed and UDim2.fromOffset(290, 56) or UDim2.fromOffset(290, 340)
collapseButton.Text = menuCollapsed and "+" or "-"

local function getBombToolName()
    if selectedBombType == "Gold Bomb" then
        return "GoldBomb"
    elseif selectedBombType == "Firefly Jar" then
        return "Fireflies"
    end
    return "FakeBomb"
end

local BombStyleRuntime = {}

BombStyleRuntime.isDescending = function(humanoid, rootPart)
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return false
    end
    local state = humanoid:GetState()
    return (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown)
        and rootPart.AssemblyLinearVelocity.Y <= -Config.BOMB_LAUNCH_FALL_SPEED
end

BombStyleRuntime.usesInstantFreefallLaunch = function()
    -- Both styles use the validated Legit dispatch path; only the bounce differs.
    return false
end

BombStyleRuntime.usesRelativeBombThrow = function()
    return selectedBombType == "Bomb"
end


local function snapshotExistingFireflyLids()
    local snapshot = {}
    for _, instance in ipairs(Workspace:GetChildren()) do
        if instance.Name == "Handle2" and instance:IsA("BasePart") then
            snapshot[instance] = true
        end
    end
    return snapshot
end

local function getBombPing(player)
    local ok, ping = pcall(function()
        return player:GetNetworkPing()
    end)
    if not ok or type(ping) ~= "number" then
        return 0
    end
    return math.clamp(ping, 0, 1.0)
end

local function getBombDataPing()
    local value = 0
    pcall(function()
        local network = Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        local item = serverStats and serverStats:FindFirstChild("Data Ping")
        if item then
            local raw = item:GetValueString()
            local number = tonumber(string.match(raw, "[%d%.]+"))
            if number then
                value = number / 1000
            end
        end
    end)
    return math.clamp(value, 0, 1.0)
end

local function getBombOneWayLatency(player)
    local networkPing = getBombPing(player)
    local dataPing = getBombDataPing()
    local effectivePing = math.max(networkPing, dataPing)
    return math.clamp(effectivePing * 0.5, 0, 0.15), effectivePing
end



local function getFootData(character, rootPart)
    local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
    local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")

    if leftFoot and rightFoot and leftFoot:IsA("BasePart") and rightFoot:IsA("BasePart") then
        local center = (leftFoot.Position + rightFoot.Position) * 0.5
        local leftBottom = leftFoot.Position.Y - leftFoot.Size.Y * 0.5
        local rightBottom = rightFoot.Position.Y - rightFoot.Size.Y * 0.5
        return center, math.min(leftBottom, rightBottom)
    end

    if leftFoot and leftFoot:IsA("BasePart") then
        return leftFoot.Position, leftFoot.Position.Y - leftFoot.Size.Y * 0.5
    end

    if rightFoot and rightFoot:IsA("BasePart") then
        return rightFoot.Position, rightFoot.Position.Y - rightFoot.Size.Y * 0.5
    end

    return rootPart.Position, rootPart.Position.Y - rootPart.Size.Y * 0.5
end

local function getMovementVelocity(humanoid, rootPart)
    local actualVelocity = rootPart.AssemblyLinearVelocity
    local horizontalVelocity = Vector3.new(actualVelocity.X, 0, actualVelocity.Z)
    local intendedVelocity = Vector3.zero

    pcall(function()
        local moveVelocity = humanoid:GetMoveVelocity()
        intendedVelocity = Vector3.new(moveVelocity.X, 0, moveVelocity.Z)
    end)

    if horizontalVelocity.Magnitude < 0.75 and intendedVelocity.Magnitude > 0.75 then
        horizontalVelocity = intendedVelocity
    end

    return horizontalVelocity
end

local function solveDescendingGroundHitTime(startY, verticalVelocity, targetY, gravity)
    local delta = verticalVelocity * verticalVelocity - 2 * gravity * (targetY - startY)
    if delta < 0 then
        return nil
    end

    local root = math.sqrt(delta)
    local first = (verticalVelocity - root) / gravity
    local second = (verticalVelocity + root) / gravity
    local best = -math.huge

    if first > 0.01 then
        best = math.max(best, first)
    end
    if second > 0.01 then
        best = math.max(best, second)
    end

    if best == -math.huge then
        return nil
    end

    return best
end

local function raycastGroundAt(character, bombTool, targetXZ, originY, rayLength)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character, bombTool}
    raycastParams.IgnoreWater = false

    local castOriginY = originY or (targetXZ.Y + Config.BOMB_TARGET_RAY_HEIGHT)
    local castLength = rayLength or Config.BOMB_TARGET_RAY_LENGTH
    local origin = Vector3.new(targetXZ.X, castOriginY, targetXZ.Z)
    return Workspace:Raycast(origin, Vector3.new(0, -castLength, 0), raycastParams)
end

local function getPredictedBombTarget(character, humanoid, rootPart, bombTool, player)
    local footCenter, footBottomY = getFootData(character, rootPart)
    local horizontalVelocity = getMovementVelocity(humanoid, rootPart)
    local horizontalSpeed = horizontalVelocity.Magnitude
    local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
    local ping = getBombPing(player)

    local moveDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
    if moveDirection.Magnitude > 0.001 then
        moveDirection = moveDirection.Unit
    elseif horizontalSpeed > 0.75 then
        moveDirection = horizontalVelocity.Unit
    else
        local lookVector = rootPart.CFrame.LookVector
        moveDirection = Vector3.new(lookVector.X, 0, lookVector.Z)
        if moveDirection.Magnitude > 0.001 then
            moveDirection = moveDirection.Unit
        else
            moveDirection = Vector3.zero
        end
    end

    local currentGround = raycastGroundAt(character, bombTool, footCenter)
    local groundedDistance = math.huge
    if currentGround then
        groundedDistance = math.abs(footBottomY - currentGround.Position.Y)
    end

    local nearGround = groundedDistance <= 0.85
    local oneWayLatency = math.clamp(ping * 0.5, 0, 0.08)
    local verticalInfluence = math.clamp(math.abs(verticalVelocity) / 60, 0, 1)

    local predictionHorizon = math.clamp(
        Config.BOMB_PREDICTION_INPUT_BASE
        + oneWayLatency * Config.BOMB_PREDICTION_PING_SCALE
        + verticalInfluence * 0.004,
        Config.BOMB_PREDICTION_INPUT_BASE,
        Config.BOMB_PREDICTION_INPUT_MAX
    )

    if nearGround then
        predictionHorizon = math.min(predictionHorizon, 0.010)
    elseif verticalVelocity > 4 then
        predictionHorizon = math.min(predictionHorizon, 0.014)
    elseif verticalVelocity < -4 then
        predictionHorizon = math.min(predictionHorizon, 0.018)
    end

    local horizontalPrediction = horizontalVelocity * predictionHorizon
    if horizontalPrediction.Magnitude > Config.BOMB_MAX_HORIZONTAL_PREDICTION then
        horizontalPrediction = horizontalPrediction.Unit * Config.BOMB_MAX_HORIZONTAL_PREDICTION
    end

    if nearGround then
        horizontalPrediction = horizontalPrediction * 0.20
    elseif verticalVelocity > 4 then
        horizontalPrediction = horizontalPrediction * 0.45
    elseif verticalVelocity < -4 then
        horizontalPrediction = horizontalPrediction * 0.70
    end

    local forwardDistance = math.clamp(
        Config.BOMB_FORWARD_BIAS
        + horizontalSpeed * Config.BOMB_FORWARD_SPEED_SCALE
        + oneWayLatency * Config.BOMB_FORWARD_PING_SCALE,
        Config.BOMB_FORWARD_BIAS,
        Config.BOMB_FORWARD_MAX
    )

    if nearGround then
        forwardDistance = math.min(forwardDistance, 0.070)
    elseif verticalVelocity > 4 then
        forwardDistance = math.min(forwardDistance, 0.065)
    elseif verticalVelocity < -4 then
        forwardDistance = math.min(forwardDistance, 0.095)
    else
        forwardDistance = math.min(forwardDistance, 0.085)
    end

    local targetXZ = footCenter + horizontalPrediction + moveDirection * forwardDistance
    local groundResult = raycastGroundAt(character, bombTool, targetXZ)

    if currentGround and groundResult then
        local surfaceRise = groundResult.Position.Y - currentGround.Position.Y
        if surfaceRise > Config.BOMB_MAX_SURFACE_RISE then
            targetXZ = footCenter + horizontalPrediction * 0.10 + moveDirection * math.min(forwardDistance, 0.045)
            groundResult = raycastGroundAt(character, bombTool, targetXZ)
        end

        if groundResult and groundResult.Position.Y - currentGround.Position.Y > Config.BOMB_MAX_SURFACE_RISE then
            groundResult = currentGround
            targetXZ = currentGround.Position
        end
    elseif not groundResult and currentGround then
        groundResult = currentGround
        targetXZ = currentGround.Position
    end

    local aimDrop = math.clamp(Config.BOMB_AIM_DROP_BASE, Config.BOMB_AIM_DROP_BASE, Config.BOMB_AIM_DROP_MAX)

    if groundResult then
        return Vector3.new(
            groundResult.Position.X,
            groundResult.Position.Y - aimDrop,
            groundResult.Position.Z
        ), targetXZ - footCenter, groundResult.Instance, predictionHorizon
    end

    return Vector3.new(
        targetXZ.X,
        footBottomY - aimDrop,
        targetXZ.Z
    ), targetXZ - footCenter, nil, predictionHorizon
end

BombStyleRuntime.getBombWorldVerticalBounds = function(bombPart, character, bombTool, containerOverride)
    local candidate = bombPart
    if not candidate and bombTool then
        candidate = bombTool:FindFirstChild("Handle") or bombTool:FindFirstChildWhichIsA("BasePart", true)
    end

    local container = containerOverride
    if not container and candidate then
        local cursor = candidate.Parent
        while cursor and cursor ~= Workspace do
            if cursor:IsA("Model") and cursor ~= character then
                local lowerName = string.lower(cursor.Name)
                if lowerName:find("bomb")
                    or lowerName:find("bomba")
                    or lowerName:find("explosive")
                    or lowerName:find("explosivo")
                    or lowerName:find("tnt")
                    or lowerName:find("dynamite") then
                    container = cursor
                    break
                end
            end
            cursor = cursor.Parent
        end
    end

    local minimumY = math.huge
    local maximumY = -math.huge
    local function includePart(part)
        if not part or not part:IsA("BasePart") then
            return
        end
        local cf = part.CFrame
        local size = part.Size
        local halfHeight = 0.5 * (
            math.abs(cf.RightVector.Y) * size.X
            + math.abs(cf.UpVector.Y) * size.Y
            + math.abs(cf.LookVector.Y) * size.Z
        )
        minimumY = math.min(minimumY, part.Position.Y - halfHeight)
        maximumY = math.max(maximumY, part.Position.Y + halfHeight)
    end

    if container and container:IsA("Model") then
        for _, instance in ipairs(container:GetDescendants()) do
            includePart(instance)
        end
    elseif container and container:IsA("BasePart") then
        includePart(container)
    else
        includePart(candidate)
    end

    if minimumY == math.huge or maximumY == -math.huge then
        return nil, nil
    end
    return minimumY, maximumY
end

local function getBombThrowTarget(character, rootPart, humanoid, bombTool, player, forceBelowFeet)
    if not character or not rootPart or not humanoid then
        return nil
    end

    local footCenter, footBottomY = getFootData(character, rootPart)

    local lookVector = rootPart.CFrame.LookVector
    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

    if flatLook.Magnitude <= 0.001 then
        local moveDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
        if moveDirection.Magnitude <= 0.001 then
            flatLook = Vector3.new(0, 0, -1)
        else
            flatLook = moveDirection
        end
    end

    flatLook = flatLook.Unit

    local velocity = rootPart.AssemblyLinearVelocity
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local horizontalSpeed = horizontalVelocity.Magnitude
    local verticalVelocity = velocity.Y
    local state = humanoid:GetState()
    local isStationary = horizontalSpeed <= 0.75
    local aimDirection = flatLook
    local throwDirection = flatLook
    local relativeThrow = BombStyleRuntime.usesRelativeBombThrow()
    if isStationary then
        horizontalVelocity = Vector3.zero
        -- Keep the previously working remote orientation until its server semantics are measured.
        throwDirection = flatLook
    else
        local movementDirection = horizontalVelocity.Unit
        if relativeThrow or movementDirection:Dot(flatLook) <= 0.001 then
            -- Shift Lock can keep the body facing away from its actual travel.
            aimDirection = movementDirection
            throwDirection = movementDirection
        end
    end

    local isFreefall = state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.FallingDown
    local isFalling = forceBelowFeet == true
        or (isFreefall and verticalVelocity <= -Config.BOMB_LAUNCH_FALL_SPEED)

    if isFalling then
        local oneWayLatency = getBombOneWayLatency(player)

        local gravity = workspace.Gravity
        local futureVerticalDelta =
            verticalVelocity * oneWayLatency
            - 0.5 * gravity * oneWayLatency * oneWayLatency
        local futureHorizontalDelta = horizontalVelocity * oneWayLatency
        local predictedFootCenter = footCenter + Vector3.new(
            futureHorizontalDelta.X,
            futureVerticalDelta,
            futureHorizontalDelta.Z
        )
        local predictedFootBottomY = footBottomY + futureVerticalDelta
        local fallingSpeed = math.max(0, -verticalVelocity)
        local fallDistanceEstimate = (fallingSpeed * fallingSpeed) / (2 * gravity)

        local belowFeet = math.clamp(
            3.20
            + fallingSpeed * 0.030
            + math.clamp(fallDistanceEstimate, 0, 18) * 0.14,
            3.20,
            7.50
        )

        local forwardDistance = (relativeThrow or forceBelowFeet or isStationary) and 0 or math.clamp(
            1.50 + horizontalSpeed * 0.004,
            1.15,
            1.65
        )

        local targetXZ = Vector3.new(
            predictedFootCenter.X + aimDirection.X * forwardDistance,
            predictedFootBottomY - belowFeet,
            predictedFootCenter.Z + aimDirection.Z * forwardDistance
        )
        local targetBodyMinimumY, targetBodyMaximumY = BombStyleRuntime.getBombWorldVerticalBounds(
            nil,
            character,
            bombTool
        )
        local targetBodyHeight = targetBodyMinimumY and targetBodyMaximumY
            and math.max(0.5, targetBodyMaximumY - targetBodyMinimumY)
            or 1
        local targetBodyBottomY = targetXZ.Y - targetBodyHeight
        local groundRayOriginY = math.max(footBottomY, predictedFootBottomY)
            + Config.BOMB_FREEFALL_GROUND_RAY_MARGIN
        local groundRayLength = math.max(
            Config.BOMB_FREEFALL_GROUND_RAY_MARGIN,
            groundRayOriginY - targetBodyBottomY + Config.BOMB_FREEFALL_GROUND_RAY_MARGIN
        )
        local groundResult = raycastGroundAt(
            character,
            bombTool,
            targetXZ,
            groundRayOriginY,
            groundRayLength
        )
        local targetY = targetXZ.Y
        local targetIsGroundSurface = false
        if groundResult and groundResult.Position.Y < math.max(footBottomY, predictedFootBottomY) then
            local groundTargetY = groundResult.Position.Y + Config.BOMB_GROUND_SINK
            if groundResult.Position.Y > targetBodyBottomY then
                targetY = groundTargetY
                targetIsGroundSurface = true
            end
        end

        return Vector3.new(targetXZ.X, targetY, targetXZ.Z), targetIsGroundSurface, throwDirection
    end

    local ping = getBombPing(player)
    local highPingForward = 0

    if ping > Config.BOMB_HIGH_PING_THRESHOLD then
        highPingForward = math.clamp(
            Config.BOMB_HIGH_PING_FORWARD_MIN
            + (ping - Config.BOMB_HIGH_PING_THRESHOLD) * Config.BOMB_HIGH_PING_FORWARD_SCALE,
            Config.BOMB_HIGH_PING_FORWARD_MIN,
            Config.BOMB_HIGH_PING_FORWARD_MAX
        )
    end

    local forwardDistance
    if isStationary then
        forwardDistance = 0
    else
        forwardDistance = math.clamp(
            0.85 + horizontalSpeed * 0.002 + highPingForward,
            0.85,
            1.05 + Config.BOMB_HIGH_PING_FORWARD_MAX
        )
    end

    return rootPart.Position + Vector3.new(0, -3, 0) + aimDirection * forwardDistance, nil, throwDirection
end

local function fireBombRemote(bombTool, character, rootPart, humanoid, player, forceBelowFeet)
    if not bombTool or not character or not rootPart or not humanoid then
        return false, nil
    end

    local remote = bombTool:FindFirstChild("Remote")
    if not remote then
        return false, nil
    end

    local targetPosition, _, throwDirection = getBombThrowTarget(character, rootPart, humanoid, bombTool, player, forceBelowFeet)
    if not targetPosition then
        return false, nil
    end

    local lookVector = rootPart.CFrame.LookVector
    local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
    if flatLook.Magnitude <= 0.001 then
        flatLook = Vector3.new(0, 0, -1)
    else
        flatLook = flatLook.Unit
    end

    local throwCFrame = CFrame.lookAt(targetPosition, targetPosition + (throwDirection or flatLook))
    local throwForce = 50
    local relativeThrow = BombStyleRuntime.usesRelativeBombThrow()
    if relativeThrow then
        local v = rootPart.AssemblyLinearVelocity
        local speed = Vector3.new(v.X, 0, v.Z).Magnitude
        throwForce = speed <= 0.75 and 0 or math.clamp(speed, 0, 50)
    end
    local sentAt = os.clock()
    local trace = {sentAt = sentAt, target = targetPosition, observed = false,
        rootPosition = rootPart.Position, velocity = rootPart.AssemblyLinearVelocity,
        state = humanoid:GetState(), force = throwForce, relativeThrow = relativeThrow,
        jumpPower = humanoid.JumpPower, jumpHeight = humanoid.JumpHeight,
        useJumpPower = humanoid.UseJumpPower}

    local ok = pcall(function()
        remote:FireServer(throwCFrame, throwForce)
    end)

    BombStyleRuntime.latestTrace = trace
    task.defer(function()
        if fireflyDiag.stopped then return end
        pcall(function()
            local latency, effectivePing = getBombOneWayLatency(player)
            local v = trace.velocity
            local p = trace.rootPosition
            local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
            fireflyDiag.log("THROW", string.format(
                "localDispatch=%s; style=%s; effectiveRTT=%.0fms; prediction=%.0fms; state=%s; root=(%.2f,%.2f,%.2f); v=(%.2f,%.2f,%.2f); target=(%.2f,%.2f,%.2f); look=(%.3f,%.3f,%.3f); arg2=%.3f; relativeThrow=%s",
                tostring(ok), tostring(savedBombSettings.BombStyle), effectivePing*1000, latency*1000,
                tostring(trace.state), p.X,p.Y,p.Z, v.X,v.Y,v.Z,
                targetPosition.X,targetPosition.Y,targetPosition.Z,
                throwCFrame.LookVector.X,throwCFrame.LookVector.Y,throwCFrame.LookVector.Z,
                trace.force,tostring(trace.relativeThrow)))
            fireflyDiag.log("JUMP_SETTINGS", string.format("UseJumpPower=%s; JumpPower=%s; JumpHeight=%s",
                tostring(trace.useJumpPower),tostring(trace.jumpPower),tostring(trace.jumpHeight)))
            if hand and hand:IsA("BasePart") then
                local h = hand.Position
                fireflyDiag.log("HAND", string.format("(%.2f,%.2f,%.2f)",h.X,h.Y,h.Z))
            end
        end)
    end)

    return ok, targetPosition
end

BombStyleRuntime.traceBomb = function(trace, part, character, rootPart)
    if not trace or trace.observed or not part or not part.Parent then return end
    trace.observed = true
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local firstPosition = part.Position
    local firstVelocity = part.AssemblyLinearVelocity
    local firstAt = os.clock() - trace.sentAt
    task.defer(function()
        if fireflyDiag.stopped then return end
        pcall(function()
            local creator = part:FindFirstChild("creator")
            fireflyDiag.log("BOMB_CANDIDATE", string.format(
                "dt=%.3fs; path=%s; creator=%s; pos=(%.2f,%.2f,%.2f); v=(%.2f,%.2f,%.2f); targetError=%.2f",
                firstAt, part:GetFullName(), tostring(creator and creator.Value),
                firstPosition.X,firstPosition.Y,firstPosition.Z,
                firstVelocity.X,firstVelocity.Y,firstVelocity.Z,(firstPosition-trace.target).Magnitude))
            fireflyDiag.log("BOMB_PROPERTIES", string.format("size=(%.2f,%.2f,%.2f); anchored=%s; collide=%s; observedHorizontalSpeed=%.3f; sentArg2=%.3f",
                part.Size.X,part.Size.Y,part.Size.Z,tostring(part.Anchored),tostring(part.CanCollide),
                Vector3.new(firstVelocity.X,0,firstVelocity.Z).Magnitude,trace.force))
            local floor = raycastGroundAt(character, part, firstPosition,
                math.max(trace.rootPosition.Y,firstPosition.Y)+4,100)
            if floor then
                fireflyDiag.log("FLOOR", string.format("surfaceY=%.3f; partCenterY=%.3f; targetY=%.3f",
                    floor.Position.Y,firstPosition.Y,trace.target.Y))
            end
        end)
        for _,elapsed in ipairs({0.05,0.15,0.30,0.60}) do
            local remaining = trace.sentAt + elapsed - os.clock()
            if remaining > 0 then task.wait(remaining) end
            if fireflyDiag.stopped or character ~= LocalPlayer.Character or not rootPart.Parent then return end
            if not part.Parent then
                fireflyDiag.log("BOMB_REMOVED", string.format("observed at +%.3fs; does not prove explosion",os.clock()-trace.sentAt))
                return
            end
            pcall(function()
                local p = part.Position
                local _,feetY = getFootData(character,rootPart)
                local v = rootPart.AssemblyLinearVelocity
                local r = rootPart.Position
                local bv = part.AssemblyLinearVelocity
                fireflyDiag.log("BOMB_SAMPLE", string.format(
                    "dt=%.3fs; pos=(%.2f,%.2f,%.2f); bombV=(%.2f,%.2f,%.2f); feetY=%.2f; root=(%.2f,%.2f,%.2f); rootV=(%.2f,%.2f,%.2f); state=%s; floor=%s",
                    os.clock()-trace.sentAt,p.X,p.Y,p.Z,bv.X,bv.Y,bv.Z,feetY,r.X,r.Y,r.Z,
                    v.X,v.Y,v.Z,tostring(humanoid and humanoid:GetState()),tostring(humanoid and humanoid.FloorMaterial)))
            end)
        end
    end)
end

local bombMouseOverride = sharedEnv.__StandaloneBombJumpMouseOverride

if type(bombMouseOverride) ~= "table" then
    bombMouseOverride = {
        active = false,
        mouse = nil,
        targetCFrame = nil,
        targetPart = nil,
        screenPosition = nil,
        camera = nil,
        installed = false,
    }
    sharedEnv.__StandaloneBombJumpMouseOverride = bombMouseOverride

    if type(hookmetamethod) == "function" then
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", (type(newcclosure) == "function" and newcclosure or function(fn) return fn end)(function(self, key)
            local state = sharedEnv.__StandaloneBombJumpMouseOverride

            if state and state.active and self == state.mouse then
                if key == "Hit" or key == "hit" then
                    return state.targetCFrame
                end

                if key == "Target" or key == "target" then
                    return state.targetPart
                end

                if key == "X" or key == "x" then
                    return state.screenPosition and state.screenPosition.X or oldIndex(self, key)
                end

                if key == "Y" or key == "y" then
                    return state.screenPosition and state.screenPosition.Y or oldIndex(self, key)
                end

                if key == "Origin" then
                    return state.camera and state.camera.CFrame or oldIndex(self, key)
                end

                if key == "UnitRay" then
                    local camera = state.camera
                    local targetCFrame = state.targetCFrame
                    if camera and targetCFrame then
                        local origin = camera.CFrame.Position
                        local direction = targetCFrame.Position - origin
                        if direction.Magnitude > 0.001 then
                            return Ray.new(origin, direction.Unit)
                        end
                    end
                end
            end

            return oldIndex(self, key)
        end))
        bombMouseOverride.installed = true
    end
end

local function setBombMouseOverride(camera, screenPosition, targetPosition, targetPart)
    bombMouseOverride.mouse = LocalPlayer:GetMouse()
    bombMouseOverride.camera = camera
    bombMouseOverride.screenPosition = screenPosition
    bombMouseOverride.targetCFrame = CFrame.new(targetPosition)
    bombMouseOverride.targetPart = targetPart
    bombMouseOverride.active = bombMouseOverride.installed
end

local function clearBombMouseOverride()
    bombMouseOverride.active = false
    bombMouseOverride.mouse = nil
    bombMouseOverride.targetCFrame = nil
    bombMouseOverride.targetPart = nil
    bombMouseOverride.screenPosition = nil
    bombMouseOverride.camera = nil
end

local function performBombActivationInput(screenPosition, inputCamera, waitForActivation)
    local touchPreferred = UIS.TouchEnabled
    pcall(function()
        touchPreferred = touchPreferred and (
            not UIS.MouseEnabled
            or UIS.PreferredInput == Enum.PreferredInput.Touch
        )
    end)

    if touchPreferred then
        local touchManager
        local touchManagerOk = pcall(function()
            touchManager = game:GetService("VirtualInputManager")
            return touchManager
        end)

        if touchManagerOk and touchManager and type(touchManager.SendTouchEvent) == "function" then
            local touchId = math.floor(os.clock() * 1000000) % 2147483647
            local sent = pcall(function()
                touchManager:SendTouchEvent(
                    touchId,
                    Enum.UserInputState.Begin.Value,
                    screenPosition.X,
                    screenPosition.Y
                )

                RunService.Heartbeat:Wait()

                touchManager:SendTouchEvent(
                    touchId,
                    Enum.UserInputState.End.Value,
                    screenPosition.X,
                    screenPosition.Y
                )

                if type(touchManager.WaitForInputEventsProcessed) == "function" then
                    touchManager:WaitForInputEventsProcessed()
                end
            end)

            if sent then
                if waitForActivation then
                    local deadline = os.clock() + 0.08
                    while not waitForActivation() and os.clock() < deadline do
                        RunService.Heartbeat:Wait()
                    end
                    if waitForActivation() then
                        return true
                    end
                else
                    return true
                end
            end
        end
    end

    local virtualInputManager
    local managerOk = pcall(function()
        virtualInputManager = game:GetService("VirtualInputManager")
        return virtualInputManager
    end)

    if managerOk and virtualInputManager and type(virtualInputManager.SendMouseButtonEvent) == "function" then
        local sent = pcall(function()
            if type(virtualInputManager.SendMouseMoveEvent) == "function" then
                virtualInputManager:SendMouseMoveEvent(
                    screenPosition.X,
                    screenPosition.Y,
                    game
                )
            end

            virtualInputManager:SendMouseButtonEvent(
                screenPosition.X,
                screenPosition.Y,
                0,
                true,
                game,
                0
            )

            virtualInputManager:SendMouseButtonEvent(
                screenPosition.X,
                screenPosition.Y,
                0,
                false,
                game,
                0
            )
        end)

        if sent then
            if waitForActivation then
                local deadline = os.clock() + 0.08
                while not waitForActivation() and os.clock() < deadline do
                    RunService.Heartbeat:Wait()
                end
                if waitForActivation() then
                    return true
                end
            else
                return true
            end
        end
    end

    local sent = pcall(function()
        VirtualUser:MoveMouse(screenPosition, inputCamera)
        VirtualUser:Button1Down(screenPosition, inputCamera)
        task.wait(0.018)
        VirtualUser:Button1Up(screenPosition, inputCamera)
    end)

    if waitForActivation and sent then
        local deadline = os.clock() + 0.08
        while not waitForActivation() and os.clock() < deadline do
            RunService.Heartbeat:Wait()
        end
    end

    return sent
end

local function fireBombActivatedConnections(tool)
    local getConnections = rawget(_G, "getconnections")
    if type(getConnections) ~= "function" then
        getConnections = getgenv and getgenv().getconnections or nil
    end
    if type(getConnections) ~= "function" then
        return false
    end

    local ok, connections = pcall(getConnections, tool.Activated)
    if not ok or type(connections) ~= "table" then
        return false
    end

    local fired = false
    for _, connection in ipairs(connections) do
        local fn = connection.Function or connection.Func
        if type(fn) == "function" then
            if connection.Enabled == nil or connection.Enabled then
                pcall(fn)
                fired = true
            end
        end
    end

    return fired
end

local function getVirtualBombInput(camera, worldPosition)
    if not camera or not worldPosition then
        return nil, nil
    end

    local screenPoint = camera:WorldToScreenPoint(worldPosition)
    local viewport = camera.ViewportSize
    if viewport.X <= 0 or viewport.Y <= 0 or screenPoint.Z <= 0 then
        return nil, nil
    end

    local margin = 2
    local x = math.clamp(screenPoint.X, margin, viewport.X - margin)
    local y = math.clamp(screenPoint.Y, margin, viewport.Y - margin)
    return Vector2.new(x, y), camera.CFrame
end

local function isBombCandidate(instance, character, bombTool)
    if not instance or not instance:IsA("BasePart") or not instance.Parent then
        return false
    end
    if character and instance:IsDescendantOf(character) then
        return false
    end
    if bombTool and instance:IsDescendantOf(bombTool) then
        return false
    end

    local cursor = instance
    while cursor and cursor ~= Workspace do
        local lowerName = cursor.Name:lower()
        if lowerName:find("bomb")
            or lowerName:find("bomba")
            or lowerName:find("explosive")
            or lowerName:find("explosivo")
            or lowerName:find("tnt")
            or lowerName:find("dynamite") then
            return true
        end
        cursor = cursor.Parent
    end

    return false
end

local function findNearbyBombPart(character, bombTool, targetPosition)
    if not targetPosition then
        return nil
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character, bombTool}
    overlapParams.MaxParts = 64

    local parts = Workspace:GetPartBoundsInRadius(targetPosition, 7, overlapParams)
    local bestPart = nil
    local bestDistance = math.huge

    for _, instance in ipairs(parts) do
        if isBombCandidate(instance, character, bombTool) then
            local distance = (instance.Position - targetPosition).Magnitude
            if distance < bestDistance then
                bestDistance = distance
                bestPart = instance
            end
        end
    end

    return bestPart
end

local function getBombContainer(bombPart, character)
    if not bombPart then
        return nil
    end

    local matchingModel = nil
    local cursor = bombPart.Parent

    while cursor and cursor ~= Workspace do
        if cursor:IsA("Model") and cursor ~= character then
            local lowerName = string.lower(cursor.Name)
            if lowerName:find("bomb")
                or lowerName:find("bomba")
                or lowerName:find("explosive")
                or lowerName:find("explosivo")
                or lowerName:find("tnt")
                or lowerName:find("dynamite") then
                matchingModel = cursor
                break
            end
        end
        cursor = cursor.Parent
    end

    return matchingModel or bombPart
end

local function getBombHeight(bombPart, container)
    if container and container:IsA("Model") then
        local ok, size = pcall(function()
            return container:GetExtentsSize()
        end)
        if ok and size.Y > 0 then
            return size.Y
        end
    end

    if bombPart and bombPart:IsA("BasePart") then
        return bombPart.Size.Y
    end

    return 1
end

local function placeBombAtTarget(bombPart, character, targetPosition, placementMode)
    if not bombPart or not targetPosition or not bombPart.Parent then
        return false
    end

    local container = getBombContainer(bombPart, character)
    local height = getBombHeight(bombPart, container)
    local currentMinimumY, currentMaximumY = BombStyleRuntime.getBombWorldVerticalBounds(
        bombPart,
        character,
        nil,
        container
    )

    local positioned = pcall(function()
        local boundsPosition
        if container and container:IsA("Model") then
            boundsPosition = container:GetBoundingBox().Position
        else
            boundsPosition = bombPart.Position
        end

        local translation
        if placementMode == "top" and currentMaximumY then
            translation = Vector3.new(
                targetPosition.X - boundsPosition.X,
                targetPosition.Y - currentMaximumY,
                targetPosition.Z - boundsPosition.Z
            )
        elseif placementMode == "surface" and currentMinimumY then
            local surfaceY = targetPosition.Y - Config.BOMB_GROUND_SINK
            translation = Vector3.new(
                targetPosition.X - boundsPosition.X,
                surfaceY - currentMinimumY,
                targetPosition.Z - boundsPosition.Z
            )
        else
            local finalPosition = Vector3.new(
                targetPosition.X,
                targetPosition.Y + height * 0.5 - Config.BOMB_GROUND_SINK,
                targetPosition.Z
            )
            translation = finalPosition - boundsPosition
        end

        if container and container:IsA("Model") then
            container:PivotTo(CFrame.new(translation) * container:GetPivot())
        else
            bombPart.CFrame = bombPart.CFrame + translation
        end
    end)
    if not positioned then
        return false
    end

    local parts = {}
    if container and container:IsA("Model") then
        for _, instance in ipairs(container:GetDescendants()) do
            if instance:IsA("BasePart") then
                parts[#parts + 1] = instance
            end
        end
    else
        parts[1] = bombPart
    end

    for _, part in ipairs(parts) do
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    return true
end

local function findFireflyRightShoulder(character)
    if not character then
        return nil
    end

    local torso = character:FindFirstChild("Torso")
    local upperTorso = character:FindFirstChild("UpperTorso")

    if torso then
        local shoulder = torso:FindFirstChild("Right Shoulder")
        if shoulder and (shoulder:IsA("Motor6D") or shoulder.ClassName == "AnimationConstraint") then
            return shoulder
        end
    end

    if upperTorso then
        local shoulder = upperTorso:FindFirstChild("RightShoulder")
        if shoulder and (shoulder:IsA("Motor6D") or shoulder.ClassName == "AnimationConstraint") then
            return shoulder
        end
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if (descendant:IsA("Motor6D") or descendant.ClassName == "AnimationConstraint")
            and (descendant.Name == "Right Shoulder" or descendant.Name == "RightShoulder") then
            return descendant
        end
    end

    return nil
end

local function getFireflyArmPart(shoulder, character)
    if character then
        local hand = character:FindFirstChild("RightHand")
        if hand and hand:IsA("BasePart") then
            return hand
        end

        local lowerArm = character:FindFirstChild("RightLowerArm")
        if lowerArm and lowerArm:IsA("BasePart") then
            return lowerArm
        end

        local upperArm = character:FindFirstChild("RightUpperArm")
        if upperArm and upperArm:IsA("BasePart") then
            return upperArm
        end

        local r6Arm = character:FindFirstChild("Right Arm")
        if r6Arm and r6Arm:IsA("BasePart") then
            return r6Arm
        end
    end

    if shoulder and shoulder.Part1 and shoulder.Part1:IsA("BasePart") then
        return shoulder.Part1
    end

    return nil
end

local function getFireflyArmLateralPosition(shoulder, armPart)
    if not shoulder or not shoulder.Part0 or not armPart or not armPart:IsA("BasePart") then
        return nil
    end

    local torso = shoulder.Part0
    if not torso:IsA("BasePart") then
        return nil
    end

    return (armPart.Position - torso.Position):Dot(torso.CFrame.RightVector)
end

local function getFireflyRootHeight(character, humanoid, rootPart)
    local height = humanoid.HipHeight + rootPart.Size.Y * 0.5
    if not character:FindFirstChild("LowerTorso") then
        local leg = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
        if leg and leg:IsA("BasePart") then height = height + leg.Size.Y end
    end
    return height
end

local function getFireflyJumpConfirmationSpeed(humanoid)
    local speed = humanoid.UseJumpPower and humanoid.JumpPower
        or math.sqrt(math.max(0, 2 * Workspace.Gravity * humanoid.JumpHeight))
    return math.max(2, speed * 0.4)
end


local function holdFireflyJump(humanoid, character, duration, sharedDeadline)
    if fireflyDoubleJumpJumpConnection then
        fireflyDoubleJumpJumpConnection:Disconnect()
        fireflyDoubleJumpJumpConnection = nil
    end

    local deadline = sharedDeadline or (os.clock() + duration)
    fireflyDoubleJumpJumpConnection = RunService.RenderStepped:Connect(function()
        if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or os.clock() >= deadline then
            pcall(function()
                humanoid.Jump = false
            end)
            if fireflyDoubleJumpJumpConnection then
                fireflyDoubleJumpJumpConnection:Disconnect()
                fireflyDoubleJumpJumpConnection = nil
            end
            return
        end

        pcall(function()
            humanoid.Jump = true
        end)
    end)
end

local function stopFireflyForwardMovement()
    local wasActive = fireflyDoubleJumpForwardConnection ~= nil
    fireflyDoubleJumpForwardConnection = nil
    RunService:UnbindFromRenderStep(Config.FIREFLY_FORWARD_MOVEMENT_BIND_NAME)
    if wasActive then
        fireflyDiag.log("AUTO_MOVE_STOP", "forward RenderStep unbound")
    end
end

local function startFireflyForwardMovement(character, humanoid, rootPart, movementStartAt, onWindowStarted, onWindowEnded, onFailure)
    local function getFireflyLandingTime(feetGap, relativeVerticalVelocity, gravity)
        -- Keep the signed gap: feet already below the top are not a zero-height landing.
        -- A valid solution must cross the top while descending relative to the lid.
        local discriminant = relativeVerticalVelocity * relativeVerticalVelocity + 2 * gravity * feetGap
        if discriminant < 0 then return nil end
        local time = (relativeVerticalVelocity + math.sqrt(discriminant)) / gravity
        if time < 0 or relativeVerticalVelocity - gravity * time > 0 then return nil end
        return time
    end

    stopFireflyForwardMovement()

    local startAt = movementStartAt or os.clock()
    local deadline = nil
    local nextAutoTraceAt = 0
    local climbingSince = nil
    local velocitySamplePart = nil
    local velocitySamplePosition = nil
    local velocitySampleAt = 0
    local measuredLidVelocity = Vector3.zero
    local measuredLidVelocityValid = false
    local measuredLowSpeedSamples = 0
    local lidRayParams = RaycastParams.new()
    lidRayParams.FilterType = Enum.RaycastFilterType.Exclude
    lidRayParams.IgnoreWater = true
    fireflyDoubleJumpForwardConnection = true
    fireflyDiag.log("AUTO_MOVE_START", "forward RenderStep bound; startAt=" .. string.format("%.3f", startAt))

    local function stopWithFailure(message)
        fireflyDiag.log("AUTO_MOVE_FAILURE", tostring(message))
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
        stopFireflyForwardMovement()
        if onFailure then
            onFailure(message)
        end
    end

    RunService:BindToRenderStep(
        Config.FIREFLY_FORWARD_MOVEMENT_BIND_NAME,
        Enum.RenderPriority.Last.Value + 1,
        function()
            if not fireflyDoubleJumpForwardConnection then
                return
            end
            local now = os.clock()
            if not character.Parent or not humanoid.Parent or not rootPart.Parent or humanoid.Health <= 0 then
                stopWithFailure("Firefly: character unavailable")
                return
            end
            local currentState = humanoid:GetState()
            if currentState == Enum.HumanoidStateType.Climbing then
                local traceLid = fireflyDoubleJumpLid
                local traceRootPosition = rootPart.Position
                local traceRootVelocity = rootPart.AssemblyLinearVelocity
                local traceLidPosition = traceLid and traceLid.Parent == Workspace and traceLid.Position or Vector3.zero
                local horizontalDistance = math.huge
                local feetGap = math.huge
                local nearLid = false

                if traceLid and traceLid:IsA("BasePart") and traceLid.Parent == Workspace then
                    local dx = traceRootPosition.X - traceLidPosition.X
                    local dz = traceRootPosition.Z - traceLidPosition.Z
                    horizontalDistance = math.sqrt(dx * dx + dz * dz)

                    local expectedRootHeight = getFireflyRootHeight(character, humanoid, rootPart)
                    feetGap = traceRootPosition.Y - expectedRootHeight
                        - (traceLidPosition.Y + traceLid.Size.Y * 0.5)

                    local horizontalGraceRadius = math.max(traceLid.Size.X, traceLid.Size.Z) * 0.5
                        + math.max(rootPart.Size.X, rootPart.Size.Z) * 0.5 + 0.65
                    nearLid = horizontalDistance <= horizontalGraceRadius
                        and feetGap >= -1.25 and feetGap <= 1.75
                end

                if not nearLid then
                    stopWithFailure("Firefly: climbing away from lid; attempt canceled safely")
                    return
                end

                if not climbingSince then
                    climbingSince = now
                    fireflyDiag.log("CLIMBING_GRACE_BEGIN", string.format(
                        "brief climbing contact near lid; horizontalDistance=%.2f; feetGap=%.2f; grace=0.18s",
                        horizontalDistance, feetGap
                    ))
                elseif now - climbingSince >= 0.18 then
                    stopWithFailure("Firefly: climbing persisted near lid; attempt canceled safely")
                    return
                end

                if now >= nextAutoTraceAt then
                    nextAutoTraceAt = now + 0.05
                    fireflyDiag.log("AUTO_TRACE_CLIMB", string.format(
                        "state=%s; root=(%.2f,%.2f,%.2f); lid=(%.2f,%.2f,%.2f); rootV=(%.2f,%.2f,%.2f); horizontalDistance=%.2f; feetGap=%.2f; graceElapsed=%.3f; floor=%s",
                        tostring(currentState),
                        traceRootPosition.X, traceRootPosition.Y, traceRootPosition.Z,
                        traceLidPosition.X, traceLidPosition.Y, traceLidPosition.Z,
                        traceRootVelocity.X, traceRootVelocity.Y, traceRootVelocity.Z,
                        horizontalDistance, feetGap, now - climbingSince,
                        tostring(humanoid.FloorMaterial)
                    ))
                end
            else
                climbingSince = nil
            end

            if now < startAt then
                humanoid:Move(Vector3.zero, false)
                if now >= nextAutoTraceAt then
                    nextAutoTraceAt = now + 0.10
                    fireflyDiag.log("AUTO_TRACE_WAIT", string.format(
                        "before startAt; state=%s; startAt=%.3f; now=%.3f; rootY=%.2f; floor=%s",
                        tostring(currentState), startAt, now, rootPart.Position.Y, tostring(humanoid.FloorMaterial)
                    ))
                end
                return
            end

            local lid = fireflyDoubleJumpLid
            if not lid or not lid:IsA("BasePart") or lid.Parent ~= Workspace then
                humanoid:Move(Vector3.zero, false)
                if now >= startAt + 1.25 then
                    stopWithFailure("Firefly: lid not detected")
                end
                return
            end

            lidRayParams.FilterDescendantsInstances = {character, lid}
            local floorHit = Workspace:Raycast(lid.Position, Vector3.new(0, -64, 0), lidRayParams)
            local bottomGap = floorHit and (lid.Position.Y - lid.Size.Y * 0.5 - floorHit.Position.Y) or math.huge
            local reportedLidVelocity = lid.AssemblyLinearVelocity

            -- AssemblyLinearVelocity can be stale or misleading for replicated/anchored lid parts.
            -- Estimate horizontal motion from the part's actual observed displacement over a short window.
            if velocitySamplePart ~= lid or not velocitySamplePosition then
                velocitySamplePart = lid
                velocitySamplePosition = lid.Position
                velocitySampleAt = now
                measuredLidVelocity = Vector3.zero
                measuredLidVelocityValid = false
                measuredLowSpeedSamples = 0
            else
                local sampleDt = now - velocitySampleAt
                if sampleDt >= 0.03 and sampleDt <= 0.20 then
                    local observedVelocity = (lid.Position - velocitySamplePosition) / sampleDt
                    if observedVelocity.Magnitude <= 100 then
                        measuredLidVelocity = observedVelocity
                        measuredLidVelocityValid = true
                        local observedHorizontalSpeed = Vector3.new(
                            observedVelocity.X, 0, observedVelocity.Z
                        ).Magnitude
                        if observedHorizontalSpeed <= 1.0 then
                            measuredLowSpeedSamples = measuredLowSpeedSamples + 1
                        else
                            measuredLowSpeedSamples = 0
                        end
                    else
                        measuredLidVelocityValid = false
                        measuredLowSpeedSamples = 0
                    end
                    velocitySamplePosition = lid.Position
                    velocitySampleAt = now
                elseif sampleDt > 0.20 then
                    -- The sample window went stale; re-baseline instead of extrapolating old motion.
                    velocitySamplePosition = lid.Position
                    velocitySampleAt = now
                    measuredLidVelocity = Vector3.zero
                    measuredLidVelocityValid = false
                    measuredLowSpeedSamples = 0
                end
            end

            -- The lateral failure reported 14 studs/s while the visible/collidable lid
            -- stayed at the same position. An uncorroborated assembly report must not
            -- drag the character towards a future position that has not been observed.
            local measuredHorizontalVelocity = Vector3.new(
                measuredLidVelocity.X, 0, measuredLidVelocity.Z
            )
            local reportedHorizontalVelocity = Vector3.new(
                reportedLidVelocity.X, 0, reportedLidVelocity.Z
            )
            local reportedHorizontalSpeed = reportedHorizontalVelocity.Magnitude
            local measuredHorizontalSpeed = measuredHorizontalVelocity.Magnitude
            local reportedVelocityIsPlausible = reportedHorizontalSpeed >= 1.25
                and reportedHorizontalSpeed <= 24.0
            local horizontalLidVelocity = Vector3.zero
            local horizontalVelocitySource = "awaiting-position-sample"
            if measuredLidVelocityValid then
                horizontalLidVelocity = measuredHorizontalVelocity
                horizontalVelocitySource = "measured"
            end
            local selectedLidVerticalVelocity = 0
            local lidVerticalVelocitySource = "awaiting-position-sample"
            if measuredLidVelocityValid then
                selectedLidVerticalVelocity = measuredLidVelocity.Y
                lidVerticalVelocitySource = "measured"
            end

            local lidVelocity = Vector3.new(
                horizontalLidVelocity.X,
                selectedLidVerticalVelocity,
                horizontalLidVelocity.Z
            )
            local lidIsSettled = floorHit ~= nil
                and bottomGap >= -0.08
                and bottomGap <= 0.18
                and lidVelocity.Magnitude <= 1.5

            local rootHeightAboveGround = getFireflyRootHeight(character, humanoid, rootPart)

            local lidTopY = lid.Position.Y + lid.Size.Y * 0.5
            local feetGap = rootPart.Position.Y - rootHeightAboveGround - lidTopY
            local rootVelocity = rootPart.AssemblyLinearVelocity
            local verticalVelocity = rootVelocity.Y
            local relativeVerticalVelocity = verticalVelocity - lidVelocity.Y
            local gravity = math.max(Workspace.Gravity, 1)
            local expectedLandingTime = getFireflyLandingTime(feetGap, relativeVerticalVelocity, gravity)
            local landingReachable = expectedLandingTime ~= nil
            local predictedLandingTime = landingReachable and math.clamp(expectedLandingTime, 0, 0.35) or 0

            if not deadline then
                local holdTime = math.clamp((expectedLandingTime or 0) + Config.FIREFLY_SECOND_JUMP_CONFIRM_TIME,
                    Config.FIREFLY_FORWARD_HOLD_TIME, Config.FIREFLY_FORWARD_MAX_HOLD_TIME)
                deadline = now + holdTime
                fireflyDiag.log("MOVE_WINDOW_BEGIN", string.format("landingEstimate=%s; hold=%.3f",
                    expectedLandingTime and string.format("%.3f", expectedLandingTime) or "no descending intersection", holdTime))
                if onWindowStarted then onWindowStarted(deadline) end
            end
            if now >= deadline then
                pcall(function() humanoid:Move(Vector3.zero, false) end)
                stopFireflyForwardMovement()
                if onWindowEnded then onWindowEnded() end
                return
            end

            -- Keep the existing 8.4-stud lead bound even when a position update
            -- briefly reports a much faster displacement.
            local leadOffset = horizontalLidVelocity * predictedLandingTime
            if leadOffset.Magnitude > 8.4 then
                leadOffset = leadOffset.Unit * 8.4
            end

            local predictedLidPosition = lid.Position + leadOffset
            local predictedLidCFrame = lid.CFrame + leadOffset
            local horizontalRootVelocity = Vector3.new(rootVelocity.X, 0, rootVelocity.Z)
            local relativeHorizontalVelocity = horizontalRootVelocity - horizontalLidVelocity
            local rootLeadTime = math.min(predictedLandingTime, 0.08)
            local predictedRootLandingPosition = rootPart.Position
                + horizontalRootVelocity * predictedLandingTime
            local predictedRootAtLanding = Vector3.new(
                predictedRootLandingPosition.X,
                predictedLidPosition.Y + lid.Size.Y * 0.5 + rootHeightAboveGround,
                predictedRootLandingPosition.Z
            )
            local horizontalOffset = Vector3.new(
                lid.Position.X - rootPart.Position.X,
                0,
                lid.Position.Z - rootPart.Position.Z
            )
            local predictedLocalPosition = predictedLidCFrame:PointToObjectSpace(predictedRootAtLanding)
            local safeHalfX = math.max(
                0.05,
                lid.Size.X * 0.5 - math.min(rootPart.Size.X * 0.25, lid.Size.X * 0.25)
            )
            local safeHalfZ = math.max(
                0.05,
                lid.Size.Z * 0.5 - math.min(rootPart.Size.Z * 0.25, lid.Size.Z * 0.25)
            )
            local predictedWithinLandingFootprint = math.abs(predictedLocalPosition.X) <= safeHalfX
                and math.abs(predictedLocalPosition.Z) <= safeHalfZ
            local descendingIntoLid = landingReachable and relativeVerticalVelocity <= -1.0
                and feetGap >= -0.25
                and feetGap <= 2.2
                and predictedWithinLandingFootprint
                and (lidIsSettled or horizontalLidVelocity.Magnitude <= 3)

            local direction = Vector3.zero
            local captureRadius = math.clamp(math.min(lid.Size.X, lid.Size.Z) * 0.12, 0.16, 0.32)
            local remainingLandingTime = math.max(predictedLandingTime - rootLeadTime, 0.08)
            -- Work in the lid's moving reference frame. The future lid displacement
            -- is already represented by its velocity; do not add that lead twice.
            local desiredRelativeVelocity = (horizontalOffset - relativeHorizontalVelocity * rootLeadTime)
                / remainingLandingTime
            local maximumCorrectionSpeed = math.max(humanoid.WalkSpeed, 1)
            if desiredRelativeVelocity.Magnitude > maximumCorrectionSpeed then
                desiredRelativeVelocity = desiredRelativeVelocity.Unit * maximumCorrectionSpeed
            end
            local desiredWorldVelocity = horizontalLidVelocity + desiredRelativeVelocity
            local requestedWorldSpeed = desiredWorldVelocity.Magnitude
            if desiredWorldVelocity.Magnitude > maximumCorrectionSpeed then
                desiredWorldVelocity = desiredWorldVelocity.Unit * maximumCorrectionSpeed
            end
            local canSettleOnLid = descendingIntoLid
                and predictedWithinLandingFootprint
                and relativeHorizontalVelocity.Magnitude <= 1.15

            if canSettleOnLid then
                direction = horizontalLidVelocity / maximumCorrectionSpeed
                if direction.Magnitude > 1 then direction = direction.Unit end
            else
                if desiredWorldVelocity.Magnitude > 0.08 then
                    direction = desiredWorldVelocity / maximumCorrectionSpeed
                elseif horizontalOffset.Magnitude > captureRadius and not predictedWithinLandingFootprint then
                    direction = horizontalOffset / math.max(maximumCorrectionSpeed * remainingLandingTime, 0.1)
                    if direction.Magnitude > 1 then
                        direction = direction.Unit
                    end
                end
            end

            if feetGap < Config.FIREFLY_LID_APPROACH_CLEARANCE then
                if predictedWithinLandingFootprint then
                    -- Move is a target movement, not an acceleration command. Match
                    -- the support's velocity instead of commanding a backwards walk.
                    direction = horizontalLidVelocity / maximumCorrectionSpeed
                    if direction.Magnitude > 1 then direction = direction.Unit end
                else
                    -- Still outside the safe footprint at low altitude: keep the full
                    -- target-interception command rather than a reduced velocity-error delta.
                    direction = desiredWorldVelocity / maximumCorrectionSpeed
                    if direction.Magnitude > 1 then
                        direction = direction.Unit
                    end
                end
            end

            humanoid:Move(direction, false)
            if now >= nextAutoTraceAt then
                nextAutoTraceAt = now + 0.10
                fireflyDiag.log("AUTO_TRACE", string.format(
                    "state=%s; root=(%.2f,%.2f,%.2f); lid=(%.2f,%.2f,%.2f); feetGap=%.2f; landingT=%.3f; remainingT=%.3f; offset=(%.2f,%.2f); desiredWorldV=(%.2f,%.2f); dir=(%.3f,%.3f); rootV=(%.2f,%.2f); lidV=(%.2f,%.2f); lidReportedV=(%.2f,%.2f); lidReportedSpeed=%.2f; reportPlausible=%s; lidVy=%.2f; lidReportedVy=%.2f; lidVelocityYSource=%s; measuredSpeed=%.2f; lowSamples=%d; lidAnchored=%s; lidVelocitySource=%s; lidVelocityMeasured=%s; local=(%.2f,%.2f); footprint=%s; descending=%s; settle=%s; floor=%s; requestedSpeed=%.2f; speedLimit=%.2f; facing=(%.2f,%.2f); windowLeft=%.3f; landingReachable=%s; rootVy=%.2f; lidSize=(%.2f,%.2f,%.2f); lidUp=(%.2f,%.2f,%.2f)",
                    tostring(currentState),
                    rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z,
                    lid.Position.X, lid.Position.Y, lid.Position.Z,
                    feetGap, predictedLandingTime, remainingLandingTime,
                    horizontalOffset.X, horizontalOffset.Z,
                    desiredWorldVelocity.X, desiredWorldVelocity.Z,
                    direction.X, direction.Z,
                    rootVelocity.X, rootVelocity.Z,
                    lidVelocity.X, lidVelocity.Z,
                    reportedLidVelocity.X, reportedLidVelocity.Z,
                    reportedHorizontalSpeed, tostring(reportedVelocityIsPlausible),
                    selectedLidVerticalVelocity, reportedLidVelocity.Y, lidVerticalVelocitySource,
                    measuredHorizontalSpeed, measuredLowSpeedSamples,
                    tostring(lid.Anchored), horizontalVelocitySource,
                    tostring(measuredLidVelocityValid),
                    predictedLocalPosition.X, predictedLocalPosition.Z,
                    tostring(predictedWithinLandingFootprint), tostring(descendingIntoLid),
                    tostring(canSettleOnLid), tostring(humanoid.FloorMaterial), requestedWorldSpeed, maximumCorrectionSpeed,
                    rootPart.CFrame.LookVector.X, rootPart.CFrame.LookVector.Z, math.max(0,deadline-now),
                    tostring(landingReachable), verticalVelocity, lid.Size.X, lid.Size.Y, lid.Size.Z,
                    lid.CFrame.UpVector.X, lid.CFrame.UpVector.Y, lid.CFrame.UpVector.Z
                ))
            end
        end
    )
end

local function bindFireflyLid(lid)
    if not lid or not lid:IsA("BasePart") or lid.Parent ~= Workspace then
        return false
    end

    if fireflyDoubleJumpLid == lid then
        return true
    end

    fireflyDoubleJumpLid = lid
    return true
end

local cancelFireflyDoubleJump = function(preserveJump)
    pcall(function()
        local contextActionService = game:GetService("ContextActionService")
        contextActionService:UnbindAction("__FireflyDoubleJumpMovementLock")
        contextActionService:UnbindAction(Config.FIREFLY_JUMP_INPUT_LOCK_NAME)
    end)
    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid:GetAttribute("__FireflyMovementLockActive") then
            local originalWalkSpeed = humanoid:GetAttribute("__FireflyMovementLockWalkSpeed")
            if typeof(originalWalkSpeed) == "number" then
                humanoid.WalkSpeed = originalWalkSpeed
            end
            humanoid:SetAttribute("__FireflyMovementLockWalkSpeed", nil)
            humanoid:SetAttribute("__FireflyMovementLockActive", nil)
        end
    end)
    if fireflyDoubleJumpRenderConnection then
        fireflyDoubleJumpRenderConnection:Disconnect()
        fireflyDoubleJumpRenderConnection = nil
    end
    if fireflyDoubleJumpStateConnection then
        fireflyDoubleJumpStateConnection:Disconnect()
        fireflyDoubleJumpStateConnection = nil
    end
    if fireflyDoubleJumpJumpingConnection then
        fireflyDoubleJumpJumpingConnection:Disconnect()
        fireflyDoubleJumpJumpingConnection = nil
    end
    if fireflyDoubleJumpPhysicsConnection then
        fireflyDoubleJumpPhysicsConnection:Disconnect()
        fireflyDoubleJumpPhysicsConnection = nil
    end
    if fireflyDoubleJumpLidConnection then
        fireflyDoubleJumpLidConnection:Disconnect()
        fireflyDoubleJumpLidConnection = nil
    end
    if fireflySecondJumpClearConnection then
        fireflySecondJumpClearConnection:Disconnect()
        fireflySecondJumpClearConnection = nil
    end
    RunService:UnbindFromRenderStep("__FireflyDoubleJumpIdleMovementLock")
    stopFireflyForwardMovement()
    if not preserveJump and fireflyDoubleJumpJumpConnection then
        fireflyDoubleJumpJumpConnection:Disconnect()
        fireflyDoubleJumpJumpConnection = nil
    end
    fireflyDoubleJumpLid = nil
    fireflyFirstJumpTriggered = false
end

sharedEnv.__StandaloneBombJumpFireflyCleanup = function()
    cancelFireflyDoubleJump()
    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end
    fireflyTimingActive = false
    pcall(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Jump = false
            humanoid:Move(Vector3.zero, false)
        end
    end)
end

-- Keep unused legacy angle helpers outside the root chunk's live-local budget.
do
    local function getFireflyArmRotationVector(shoulder)
        if not shoulder or not shoulder:IsA("Motor6D") then
            return nil
        end

        local x, y, z = shoulder.Transform:ToOrientation()
        return Vector3.new(x, y, z)
    end

    local function wrapAngle(angle)
        return math.atan2(math.sin(angle), math.cos(angle))
    end

    local function getAngularComponent(rotation, baseline, axis)
        if not rotation or not baseline then
            return nil
        end

        if axis == 1 then
            return wrapAngle(rotation.X - baseline.X)
        elseif axis == 2 then
            return wrapAngle(rotation.Y - baseline.Y)
        end
        return wrapAngle(rotation.Z - baseline.Z)
    end
end

local function armFireflyDoubleJump(character, humanoid, rootPart, shoulder, preExistingLids, activationState)
    cancelFireflyDoubleJump()
    if not character.Parent or not humanoid.Parent or not rootPart.Parent or humanoid.Health <= 0 then
        fireflyDiag.log("ARM_SENSOR_FAILED", "character unavailable before arming")
        return false
    end

    shoulder = shoulder or findFireflyRightShoulder(character)
    if not shoulder
        or not (shoulder:IsA("Motor6D") or shoulder.ClassName == "AnimationConstraint") then
        statusLabel.Text = "Firefly: right arm sensor unavailable"
        fireflyDiag.log("ARM_SENSOR_FAILED", statusLabel.Text)
        return false
    end

    local armPart = getFireflyArmPart(shoulder, character)
    if not armPart then
        statusLabel.Text = "Firefly: right arm part unavailable"
        fireflyDiag.log("ARM_SENSOR_FAILED", statusLabel.Text)
        return false
    end

    local neutralLateral = getFireflyArmLateralPosition(shoulder, armPart)
    if neutralLateral == nil then
        statusLabel.Text = "Firefly: right arm position unavailable"
        fireflyDiag.log("ARM_SENSOR_FAILED", statusLabel.Text)
        return false
    end

    local armLength = math.max(armPart.Size.Magnitude, 0.1)
    pcall(function()
        if shoulder.Part0 and shoulder.C0 then
            local jointOrigin = shoulder.Part0.CFrame:PointToWorldSpace(shoulder.C0.Position)
            armLength = math.max((armPart.Position - jointOrigin).Magnitude, 0.1)
        end
    end)

    local initialTravelThreshold = math.max(0.025, armLength * Config.FIREFLY_ARM_INITIAL_TRAVEL_RATIO)
    local returnTravelThreshold = math.max(0.02, armLength * Config.FIREFLY_FIRST_JUMP_RETURN_RATIO)
    local phase = 0
    local firstDirection = 0
    local firstLegTravel = 0
    local returnTravel = 0
    local reversalFrames = 0
    local previousLateral = neutralLateral
    local startedAt = os.clock()
    local previousSampleAt = startedAt
    local sequenceStarted = false
    local firstJumpAirborne = false
    local firstJumpDescentObserved = false
    local firstLandingSeen = false
    local lastClimbingStateAt = nil
    local lastLandingStateAt = nil
    local inputWindowDeadline = nil
    local movementWindowDeadline = nil
    local landedOnLid = false
    local movementWindowStarted = false
    local sequenceStartedAt = nil
    local sequenceResolutionDeadline = nil
    local firstJumpRequestDeadline = nil
    local nextFirstJumpRetryAt = 0
    local secondJumpRequestDeadline = nil
    local nextSecondJumpRetryAt = 0
    local nextArmTraceAt = 0

    statusLabel.Text = "Firefly: tracking right arm"
    fireflyDiag.log("ARM_SENSOR", string.format("rig=%s; shoulder=%s; sensor=%s; neutral=%.4f; initialThreshold=%.4f; returnThreshold=%.4f; hipHeight=%.3f; rootHeight=%.3f",
        tostring(humanoid.RigType),tostring(shoulder.ClassName),armPart.Name,neutralLateral,
        initialTravelThreshold,returnTravelThreshold,humanoid.HipHeight,getFireflyRootHeight(character,humanoid,rootPart)))

    local function lockMovement()
        fireflyDiag.log("PLAYER_LOCK_BEGIN", "temporary movement/jump action sink + world-space steering; PlayerModule remains enabled")
        pcall(function()
            if not humanoid:GetAttribute("__FireflyMovementLockActive") then
                humanoid:SetAttribute("__FireflyMovementLockWalkSpeed", humanoid.WalkSpeed)
            end
            humanoid:SetAttribute("__FireflyMovementLockActive", true)
        end)
        pcall(function()
            local contextActionService = game:GetService("ContextActionService")
            contextActionService:BindActionAtPriority(
                "__FireflyDoubleJumpMovementLock",
                function()
                    return Enum.ContextActionResult.Sink
                end,
                false,
                10000,
                Enum.PlayerActions.CharacterJump,
                Enum.PlayerActions.CharacterForward,
                Enum.PlayerActions.CharacterBackward,
                Enum.PlayerActions.CharacterLeft,
                Enum.PlayerActions.CharacterRight,
                Enum.KeyCode.Space,
                Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
                Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
                Enum.KeyCode.Thumbstick1
            )
        end)
        RunService:BindToRenderStep(
            "__FireflyDoubleJumpIdleMovementLock",
            Enum.RenderPriority.Last.Value + 2,
            function()
                if fireflyDoubleJumpForwardConnection then
                    return
                end
                if character.Parent and humanoid.Parent and humanoid.Health > 0 then
                    humanoid:Move(Vector3.zero, false)
                end
            end
        )
    end

    local function clearFireflyJumpAfterSimulation()
        if fireflySecondJumpClearConnection then
            fireflySecondJumpClearConnection:Disconnect()
            fireflySecondJumpClearConnection = nil
        end

        local connection
        connection = RunService.PostSimulation:Connect(function()
            fireflyDiag.log("JUMP_FLAG_CLEAR", "PostSimulation clearing humanoid.Jump")
            connection:Disconnect()
            if fireflySecondJumpClearConnection == connection then
                fireflySecondJumpClearConnection = nil
            end
            if humanoid and humanoid.Parent then
                pcall(function()
                    humanoid.Jump = false
                end)
            end
        end)
        fireflySecondJumpClearConnection = connection
    end

    local function isCharacterAirborne()
        if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or not rootPart.Parent then
            return false
        end

        local state = humanoid:GetState()
        local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
        if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
            return true
        end
        if state == Enum.HumanoidStateType.Jumping and verticalVelocity > 2 then
            return true
        end

        return humanoid.FloorMaterial == Enum.Material.Air and math.abs(verticalVelocity) > 3.5
    end

    local function isCharacterGrounded()
        if not character.Parent or not humanoid.Parent or humanoid.Health <= 0 or not rootPart.Parent then
            return false
        end

        local state = humanoid:GetState()
        local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
        return humanoid.FloorMaterial ~= Enum.Material.Air
            and math.abs(verticalVelocity) <= 1.5
            and state ~= Enum.HumanoidStateType.Jumping
            and state ~= Enum.HumanoidStateType.Freefall
            and state ~= Enum.HumanoidStateType.FallingDown
            and state ~= Enum.HumanoidStateType.Climbing
    end

    local function getGroundPart(allowStateTransition)
        if not allowStateTransition and not isCharacterGrounded() then
            return nil
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {character}
        rayParams.IgnoreWater = true

        local rayLength = math.max(getFireflyRootHeight(character, humanoid, rootPart) + 1.5, 4)
        local lid = fireflyDoubleJumpLid
        local result = Workspace:Raycast(rootPart.Position, Vector3.new(0, -rayLength, 0), rayParams)
        local centerHitInstance = result and result.Instance or nil

        local function isLidTopHit(hit)
            if not hit or not lid or lid.Parent ~= Workspace or hit.Instance ~= lid then
                return false
            end
            local localHitPosition = lid.CFrame:PointToObjectSpace(hit.Position)
            return hit.Normal:Dot(lid.CFrame.UpVector) >= 0.7
                and math.abs(localHitPosition.Y - lid.Size.Y * 0.5) <= 0.20
                and math.abs(localHitPosition.X) <= lid.Size.X * 0.5
                and math.abs(localHitPosition.Z) <= lid.Size.Z * 0.5
        end

        if isLidTopHit(result) then
            return lid
        end

        if lid and lid.Parent == Workspace then
            local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
            local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
            for _, foot in pairs({leftFoot, rightFoot}) do
                if foot:IsA("BasePart") then
                    local footOrigin = Vector3.new(foot.Position.X,
                        math.max(rootPart.Position.Y, foot.Position.Y + 0.5), foot.Position.Z)
                    local hit = Workspace:Raycast(footOrigin, Vector3.new(0, -rayLength, 0), rayParams)
                    if isLidTopHit(hit) then return lid end
                end
            end
            -- The character can physically touch the top with its feet while the root-center
            -- ray falls just outside the lid's edge. Probe a small cross around the root, but
            -- still require a real ray hit on the lid's top face to avoid treating side contact
            -- or a nearby floor as a successful landing.
            local right = Vector3.new(rootPart.CFrame.RightVector.X, 0, rootPart.CFrame.RightVector.Z)
            local forward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
            if right.Magnitude > 0.001 then right = right.Unit else right = Vector3.xAxis end
            if forward.Magnitude > 0.001 then forward = forward.Unit else forward = Vector3.zAxis end
            local sideOffset = math.max(rootPart.Size.X * 0.35, 0.2)
            local forwardOffset = math.max(rootPart.Size.Z * 0.35, 0.2)
            local probeOffsets = {
                right * sideOffset,
                -right * sideOffset,
                forward * forwardOffset,
                -forward * forwardOffset,
            }
            for _, offset in ipairs(probeOffsets) do
                local hit = Workspace:Raycast(rootPart.Position + offset, Vector3.new(0, -rayLength, 0), rayParams)
                if isLidTopHit(hit) then
                    return lid
                end
            end
        end

        if centerHitInstance == lid then
            return nil
        end
        return centerHitInstance
    end

    local secondJumpRequested = false
    local secondJumpDetected = false
    local secondJumpRequestStartedAt = nil
    local secondJumpRequestInitialRelativeVelocity = nil

    local function issueSecondJumpRequest()
        fireflyDiag.log("JUMP_REQUEST_ISSUE", "state=" .. tostring(humanoid:GetState())
            .. "; floor=" .. tostring(humanoid.FloorMaterial)
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y)
            .. "; seq=" .. tostring(sequenceStarted)
            .. "; lid=" .. tostring(fireflyDoubleJumpLid and fireflyDoubleJumpLid.Name))
        if fireflyDoubleJumpJumpConnection then
            fireflyDoubleJumpJumpConnection:Disconnect()
            fireflyDoubleJumpJumpConnection = nil
        end

        pcall(function()
            humanoid.Jump = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        fireflyDiag.log("JUMP_REQUEST_SENT", "state now=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y))
        -- Do not clear Jump in the same simulation step as the request.
        -- The request may otherwise be canceled before the second takeoff begins.
        -- releaseAfterSecondJump clears it after detecting the actual takeoff.
    end

    local function releaseAfterSecondJump(detectionSource)
        fireflyDiag.log("RELEASE_HANDLER_ENTER", "source=" .. tostring(detectionSource)
            .. "; alreadyDetected=" .. tostring(secondJumpDetected)
            .. "; sequenceStarted=" .. tostring(sequenceStarted)
            .. "; state=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y)
            .. "; floor=" .. tostring(humanoid.FloorMaterial))
        if secondJumpDetected or not sequenceStarted then
            fireflyDiag.log("RELEASE_HANDLER_SKIP", "guard stopped release")
            return
        end

        secondJumpDetected = true
        sequenceStarted = false
        statusLabel.Text = detectionSource and ("Firefly: second jump detected (" .. detectionSource .. ")")
            or "Firefly: second jump detected"

        stopFireflyForwardMovement()
        if fireflyDoubleJumpJumpConnection then
            fireflyDoubleJumpJumpConnection:Disconnect()
            fireflyDoubleJumpJumpConnection = nil
        end
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)
        cancelFireflyDoubleJump()
        fireflyDiag.log("PLAYER_UNLOCK_DONE", "release handler completed; seq=false, movement bind/callbacks cancelled")

        clearFireflyJumpAfterSimulation()
    end

    local function requestSecondJumpOnLid()
        if secondJumpRequested or not sequenceStarted or not landedOnLid then
            fireflyDiag.log("JUMP_REQUEST_GUARD", "alreadyRequested=" .. tostring(secondJumpRequested)
                .. "; sequenceStarted=" .. tostring(sequenceStarted)
                .. "; landedOnLid=" .. tostring(landedOnLid))
            return
        end

        secondJumpRequested = true
        fireflyDiag.log("LID_JUMP_REQUEST", "recognized lid landing; requesting second jump now")
        secondJumpRequestStartedAt = os.clock()
        secondJumpRequestDeadline = secondJumpRequestStartedAt + Config.FIREFLY_SECOND_JUMP_CONFIRM_TIME
        nextSecondJumpRetryAt = secondJumpRequestStartedAt + 0.06
        local lid = fireflyDoubleJumpLid
        local lidVerticalVelocity = lid and lid.Parent == Workspace and lid.AssemblyLinearVelocity.Y or 0
        secondJumpRequestInitialRelativeVelocity = rootPart.AssemblyLinearVelocity.Y - lidVerticalVelocity
        statusLabel.Text = "Firefly: requesting second jump"
        issueSecondJumpRequest()
        -- Keep the existing movement sequence active only until the second jump
        -- actually starts; releaseAfterSecondJump handles that detection.
    end

    local function isSecondJumpBeginning()
        return firstJumpAirborne and landedOnLid and secondJumpRequested
    end

    local function registerLandedOnLid()
        fireflyDiag.log("LID_LANDING_HANDLER", "alreadyLanded=" .. tostring(landedOnLid)
            .. "; lid=" .. tostring(fireflyDoubleJumpLid))
        if landedOnLid then
            return
        end

        local lid = fireflyDoubleJumpLid
        if not lid or not lid.Parent then
            return
        end

        landedOnLid = true
        statusLabel.Text = "Firefly: landed on lid"
        requestSecondJumpOnLid()
    end

    local function finishAttempt(message)
        fireflyDiag.log("ATTEMPT_FINISH", tostring(message or "no message")
            .. "; state=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y)
            .. "; seq=" .. tostring(sequenceStarted))
        if message then
            statusLabel.Text = message
        end

        pcall(function()
            humanoid.Jump = false
            humanoid:Move(Vector3.zero, false)
        end)
        cancelFireflyDoubleJump()
        sequenceStarted = false
    end

    local function requestFirstJumpAgain()
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            humanoid.Jump = true
        end)
    end

    local function handleLandedGroundPart(groundPart, now)
        local lid = fireflyDoubleJumpLid
        if groundPart and lid and lid.Parent == Workspace and groundPart == lid then
            registerLandedOnLid()
            return false
        end

        if not groundPart then
            return false
        end

        if (not lid or lid.Parent ~= Workspace) and sequenceStartedAt and now < sequenceStartedAt + 1.25 then
            firstJumpAirborne = false
            statusLabel.Text = "Firefly: waiting for lid"
            return false
        end

        finishAttempt("Firefly: landed off lid")
        return true
    end

    local function beginTimedSequence()
        if sequenceStarted or fireflyFirstJumpTriggered
            or not character.Parent or humanoid.Health <= 0 or not rootPart.Parent then
            return false
        end

        local wasAirborneAtTrigger = isCharacterAirborne()
        lockMovement()
        pcall(function()
            humanoid:Move(Vector3.zero, false)
        end)

        sequenceStarted = true
        fireflyFirstJumpTriggered = true
        sequenceStartedAt = os.clock()
        firstJumpAirborne = false
        firstJumpDescentObserved = false
        firstLandingSeen = false
        lastClimbingStateAt = nil
        lastLandingStateAt = nil
        landedOnLid = false
        movementWindowStarted = false
        movementWindowDeadline = nil
        secondJumpRequested = false
        secondJumpDetected = false
        secondJumpRequestStartedAt = nil
        secondJumpRequestInitialRelativeVelocity = nil
        secondJumpRequestDeadline = nil
        nextSecondJumpRetryAt = 0
        if wasAirborneAtTrigger then
            firstJumpRequestDeadline = nil
        else
            firstJumpRequestDeadline = sequenceStartedAt + 0.22
        end
        nextFirstJumpRetryAt = sequenceStartedAt + 0.04
        sequenceResolutionDeadline = sequenceStartedAt + 2.0
        statusLabel.Text = wasAirborneAtTrigger and "Firefly: waiting for fresh jump" or "Firefly: first jump"
        fireflyDiag.log("SEQUENCE_BEGIN", string.format("airborneAtTrigger=%s; state=%s; rootVy=%.2f; lateral=%.4f; firstTravel=%.4f; returnTravel=%.4f",
            tostring(wasAirborneAtTrigger),tostring(humanoid:GetState()),rootPart.AssemblyLinearVelocity.Y,
            previousLateral,firstLegTravel,returnTravel))

        inputWindowDeadline = sequenceStartedAt + Config.FIREFLY_FIRST_JUMP_HOLD_TIME
        local movementStartAt = sequenceStartedAt + 0.05

        if not wasAirborneAtTrigger then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
        pcall(function()
            humanoid.Jump = true
        end)

        holdFireflyJump(humanoid, character, Config.FIREFLY_FIRST_JUMP_HOLD_TIME, inputWindowDeadline)
        startFireflyForwardMovement(
            character,
            humanoid,
            rootPart,
            movementStartAt,
            function(deadline)
                movementWindowStarted = true
                movementWindowDeadline = deadline
                sequenceResolutionDeadline = deadline + 0.75
            end,
            function()
                movementWindowDeadline = nil
            end,
            function(message)
                finishAttempt(message)
            end
        )
        return true
    end

    local function confirmFirstTakeoff()
        if not sequenceStarted or firstJumpAirborne or not firstJumpRequestDeadline
            or not character.Parent or not rootPart.Parent or not humanoid.Parent or humanoid.Health <= 0 then return false end
        local state = humanoid:GetState()
        local vy = rootPart.AssemblyLinearVelocity.Y
        if humanoid.FloorMaterial == Enum.Material.Air
            and (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
            and vy >= getFireflyJumpConfirmationSpeed(humanoid) then
            firstJumpAirborne = true
            firstJumpRequestDeadline = nil
            fireflyDiag.log("FIRST_TAKEOFF_CONFIRMED", string.format("state=%s; vy=%.2f",tostring(state),vy))
            return true
        end
        return false
    end

    fireflyDoubleJumpJumpingConnection = humanoid.Jumping:Connect(function(active)
        fireflyDiag.log("JUMPING_EVENT", "active=" .. tostring(active)
            .. "; seq=" .. tostring(sequenceStarted)
            .. "; firstAirborne=" .. tostring(firstJumpAirborne)
            .. "; lidLanded=" .. tostring(landedOnLid)
            .. "; secondRequested=" .. tostring(secondJumpRequested)
            .. "; state=" .. tostring(humanoid:GetState())
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y))
        if active
            and sequenceStarted
            and character.Parent
            and humanoid.Parent
            and humanoid.Health > 0
            and isSecondJumpBeginning() then
            local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
            if verticalVelocity >= getFireflyJumpConfirmationSpeed(humanoid) then
                releaseAfterSecondJump("jump event with upward impulse")
            else
                -- The Jumping signal can fire before physics applies the actual jump
                -- impulse. Do not cancel Humanoid.Jump or release steering on that
                -- pre-impulse signal; PostSimulation confirms the real takeoff.
                fireflyDiag.log("JUMP_EVENT_WAIT_IMPULSE", "Jumping signal arrived before upward takeoff was confirmed; waiting for physics; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(humanoid:GetState())
                    .. "; floor=" .. tostring(humanoid.FloorMaterial))
            end
        end
    end)

    fireflyDoubleJumpStateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
        fireflyDiag.log("STATE_EVENT", tostring(oldState) .. " -> " .. tostring(newState)
            .. "; seq=" .. tostring(sequenceStarted)
            .. "; firstAirborne=" .. tostring(firstJumpAirborne)
            .. "; lidLanded=" .. tostring(landedOnLid)
            .. "; secondRequested=" .. tostring(secondJumpRequested)
            .. "; vy=" .. string.format("%.2f", rootPart.AssemblyLinearVelocity.Y))
        if not sequenceStarted or not character.Parent or humanoid.Health <= 0 then
            return
        end

        if newState == Enum.HumanoidStateType.Climbing then
            lastClimbingStateAt = os.clock()
            if fireflyDoubleJumpForwardConnection then
                fireflyDiag.log("CLIMBING_STATE_DEFERRED", "active steering will allow only brief near-lid contact; distant or persistent climbing is still canceled")
            else
                finishAttempt("Firefly: climbing detected without active lid steering; attempt canceled safely")
            end
            return
        end

        if newState == Enum.HumanoidStateType.Jumping then
            if isSecondJumpBeginning() then
                local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
                if verticalVelocity >= getFireflyJumpConfirmationSpeed(humanoid) then
                    releaseAfterSecondJump("state event with upward impulse")
                else
                    -- StateChanged can precede the physical jump impulse as well.
                    -- Keep the sequence alive until PostSimulation sees real takeoff.
                    fireflyDiag.log("STATE_EVENT_WAIT_IMPULSE", "Jumping state arrived before upward takeoff was confirmed; waiting for physics; vy="
                        .. string.format("%.2f", verticalVelocity)
                        .. "; state=" .. tostring(newState)
                        .. "; floor=" .. tostring(humanoid.FloorMaterial))
                end
                return
            end

            confirmFirstTakeoff()
            return
        end

        if newState == Enum.HumanoidStateType.Landed and firstJumpAirborne then
            lastLandingStateAt = os.clock()
            firstLandingSeen = true
            fireflyDiag.log("FIRST_LANDING_OBSERVED", "the first airborne phase has ended; a later upward takeoff can release controls even if lid detection fails")
            local landedPart = getGroundPart(true)
            fireflyDiag.log("LANDED_STATE", "groundPart=" .. tostring(landedPart)
                .. "; lid=" .. tostring(fireflyDoubleJumpLid)
                .. "; matches=" .. tostring(landedPart ~= nil and landedPart == fireflyDoubleJumpLid))
            handleLandedGroundPart(landedPart, os.clock())
        end
    end)

    local lastSecondJumpPhysicsDiagAt = 0
    fireflyDoubleJumpPhysicsConnection = RunService.PostSimulation:Connect(function()
        confirmFirstTakeoff()
        if not sequenceStarted
            or not firstJumpAirborne
            or secondJumpDetected
            or not character.Parent
            or not rootPart.Parent
            or not humanoid.Parent
            or humanoid.Health <= 0 then
            return
        end

        -- A brief physical landing can occur between rendered frames without a
        -- matching StateChanged callback. Require the same grounded/top-face check.
        if not landedOnLid and fireflyDoubleJumpLid ~= nil
            and isCharacterGrounded() and getGroundPart() == fireflyDoubleJumpLid then
            fireflyDiag.log("LID_PHYSICS_CONTACT", "grounded top-face contact observed after simulation")
            firstLandingSeen = true
            registerLandedOnLid()
        end

        -- Remember that the first airborne phase has genuinely entered descent.
        -- Some Firefly attempts touch the lid's side, transition Climbing -> Running,
        -- and take off again without ever producing HumanoidStateType.Landed. The old
        -- fallback required firstLandingSeen, so it missed that second takeoff and left
        -- forward steering active until its timer expired.
        local currentState = humanoid:GetState()
        local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
        if not firstJumpDescentObserved
            and verticalVelocity <= -4.0
            and (currentState == Enum.HumanoidStateType.Freefall
                or currentState == Enum.HumanoidStateType.FallingDown
                or currentState == Enum.HumanoidStateType.Climbing
                or currentState == Enum.HumanoidStateType.Landed) then
            firstJumpDescentObserved = true
            fireflyDiag.log("FIRST_DESCENT_OBSERVED", "downward phase confirmed; later upward takeoff can release even without Landed; vy="
                .. string.format("%.2f", verticalVelocity)
                .. "; state=" .. tostring(currentState))
        end

        if firstJumpDescentObserved
            and verticalVelocity >= getFireflyJumpConfirmationSpeed(humanoid)
            and (currentState == Enum.HumanoidStateType.Jumping
                or currentState == Enum.HumanoidStateType.Freefall) then
            local recentClimbingContact = lastClimbingStateAt ~= nil
                and os.clock() - lastClimbingStateAt <= 0.25
                and (lastLandingStateAt == nil or lastLandingStateAt < lastClimbingStateAt)
            if recentClimbingContact and not (landedOnLid and secondJumpRequested) then
                fireflyDiag.log("NON_LID_REBOUND_ABORT", "upward impulse followed recent Climbing contact without a confirmed lid-jump request; restoring controls; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=" .. tostring(landedOnLid)
                    .. "; secondRequested=" .. tostring(secondJumpRequested))
                finishAttempt("Firefly: side-climb rebound; controls restored")
            elseif landedOnLid and secondJumpRequested then
                fireflyDiag.log("POST_DESCENT_TAKEOFF", "confirmed upward impulse after requested lid jump; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=true; secondRequested=true; releasing controls now")
                releaseAfterSecondJump("confirmed post-descent lid jump impulse")
            else
                -- Preserve the fallback for cases where contact happened on the top edge but
                -- the root-center ray still did not recognize the lid. Recent side-climb contact
                -- is excluded above so this does not misclassify the lateral rebound as success.
                fireflyDiag.log("POST_DESCENT_TAKEOFF_FALLBACK", "upward impulse after descent without recent Climbing; releasing controls; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=" .. tostring(landedOnLid)
                    .. "; secondRequested=" .. tostring(secondJumpRequested))
                releaseAfterSecondJump("post-descent takeoff fallback")
            end
            return
        end

        -- Keep the earlier landed-state fallback as a lower-threshold backup for
        -- legitimate takeoffs whose upward impulse is weaker than the general detector.
        if firstLandingSeen and (not landedOnLid or not secondJumpRequested) then
            local currentState = humanoid:GetState()
            local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
            if verticalVelocity >= getFireflyJumpConfirmationSpeed(humanoid)
                and (currentState == Enum.HumanoidStateType.Jumping
                    or currentState == Enum.HumanoidStateType.Freefall) then
                fireflyDiag.log("POST_LANDING_TAKEOFF", "fallback detected upward velocity; vy="
                    .. string.format("%.2f", verticalVelocity)
                    .. "; state=" .. tostring(currentState)
                    .. "; lidLanded=" .. tostring(landedOnLid)
                    .. "; secondRequested=" .. tostring(secondJumpRequested)
                    .. "; releasing controls now")
                releaseAfterSecondJump("post-landing takeoff fallback")
            end
            return
        end

        if not landedOnLid or not secondJumpRequested then
            return
        end

        local requestStartedAt = secondJumpRequestStartedAt
        if not requestStartedAt then
            return
        end

        local elapsedSinceRequest = os.clock() - requestStartedAt
        if elapsedSinceRequest <= 0 or elapsedSinceRequest > 0.45 then
            return
        end

        local lid = fireflyDoubleJumpLid
        local lidVerticalVelocity = 0
        if lid and lid.Parent == Workspace then
            lidVerticalVelocity = lid.AssemblyLinearVelocity.Y
        end

        local playerVerticalVelocity = rootPart.AssemblyLinearVelocity.Y
        local playerState = humanoid:GetState()
        local relativeVerticalVelocity = playerVerticalVelocity - lidVerticalVelocity
        local initialRelativeVelocity = secondJumpRequestInitialRelativeVelocity or 0
        local upwardVelocityChange = relativeVerticalVelocity - initialRelativeVelocity
        if os.clock() - lastSecondJumpPhysicsDiagAt >= 0.06 then
            lastSecondJumpPhysicsDiagAt = os.clock()
            fireflyDiag.log("PHYSICS_CHECK", "t=" .. string.format("%.3f", elapsedSinceRequest)
                .. "; rootVy=" .. string.format("%.2f", playerVerticalVelocity)
                .. "; relVy=" .. string.format("%.2f", relativeVerticalVelocity)
                .. "; deltaVy=" .. string.format("%.2f", upwardVelocityChange)
                .. "; state=" .. tostring(playerState)
                .. "; floor=" .. tostring(humanoid.FloorMaterial))
        end

        -- The lid can move independently and create a large relative-velocity change
        -- while the character is still grounded. Never treat lid-relative motion alone
        -- as proof that the player's second jump has begun.
        if playerVerticalVelocity >= getFireflyJumpConfirmationSpeed(humanoid)
            and (playerState == Enum.HumanoidStateType.Jumping
                or playerState == Enum.HumanoidStateType.Freefall)
            and relativeVerticalVelocity >= 2.0
            and upwardVelocityChange >= 1.5 then
            releaseAfterSecondJump("physics impulse confirmed by player ascent")
        end
    end)

    local function handleFireflyLidAppearance(lid)
        if not lid or not lid:IsA("BasePart") or lid.Parent ~= Workspace then
            return
        end
        if preExistingLids and preExistingLids[lid] then
            return
        end
        if fireflyDoubleJumpLid and fireflyDoubleJumpLid.Parent and fireflyDoubleJumpLid ~= lid then
            return
        end
        local creator = lid:FindFirstChild("creator")
        if creator and creator:IsA("ObjectValue") and creator.Value
            and creator.Value:IsA("Player") and creator.Value ~= LocalPlayer then
            fireflyDiag.log("LID_REJECTED", "another player owns "..lid:GetFullName())
            return
        end
        local distance = (lid.Position - rootPart.Position).Magnitude
        if distance > math.max(12, armLength * 4) then
            fireflyDiag.log("LID_REJECTED", string.format("outside jar vicinity; distance=%.2f; path=%s",distance,lid:GetFullName()))
            return
        end
        bindFireflyLid(lid)
        local p, v = lid.Position, lid.AssemblyLinearVelocity
        fireflyDiag.log("LID_BOUND", string.format("path=%s; distance=%.2f; pos=(%.2f,%.2f,%.2f); velocity=(%.2f,%.2f,%.2f); collide=%s; anchored=%s; creator=%s; size=(%.2f,%.2f,%.2f); up=(%.2f,%.2f,%.2f)",
            lid:GetFullName(),distance,p.X,p.Y,p.Z,v.X,v.Y,v.Z,tostring(lid.CanCollide),tostring(lid.Anchored),tostring(creator and creator.Value),
            lid.Size.X,lid.Size.Y,lid.Size.Z,lid.CFrame.UpVector.X,lid.CFrame.UpVector.Y,lid.CFrame.UpVector.Z))
    end

    fireflyDoubleJumpLidConnection = Workspace.ChildAdded:Connect(function(instance)
        if instance and instance.Name == "Handle2" and instance:IsA("BasePart")
            and instance.Parent == Workspace
            and not (preExistingLids and preExistingLids[instance]) then
            handleFireflyLidAppearance(instance)
        end
    end)

    for _, existingLid in ipairs(Workspace:GetChildren()) do
        if existingLid.Name == "Handle2" and existingLid:IsA("BasePart")
            and not (preExistingLids and preExistingLids[existingLid]) then
            handleFireflyLidAppearance(existingLid)
        end
    end

    fireflyDoubleJumpRenderConnection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if not character.Parent or not rootPart.Parent or not humanoid.Parent or humanoid.Health <= 0 then
            finishAttempt("Firefly: character unavailable")
            return
        end

        if not sequenceStarted then
            if now - startedAt > Config.FIREFLY_ARM_TRACK_TIMEOUT then
                finishAttempt("Firefly: right arm trigger timed out")
                return
            end

            local lateral = getFireflyArmLateralPosition(shoulder, armPart)
            if now >= nextArmTraceAt then
                nextArmTraceAt = now + 0.10
                fireflyDiag.log("ARM_TRACE", string.format("active=%s; phase=%d; lateral=%s; neutral=%.4f; initialTravel=%.4f; returnTravel=%.4f; rootVy=%.2f; state=%s",
                    tostring(not activationState or activationState.activated),phase,tostring(lateral),neutralLateral,
                    firstLegTravel,returnTravel,rootPart.AssemblyLinearVelocity.Y,tostring(humanoid:GetState())))
            end
            if activationState and not activationState.activated then
                if lateral ~= nil then
                    neutralLateral = lateral
                    previousLateral = lateral
                    previousSampleAt = now
                    phase = 0
                    firstDirection = 0
                    firstLegTravel = 0
                    returnTravel = 0
                    reversalFrames = 0
                end
                return
            end
            if lateral == nil then
                finishAttempt("Firefly: right arm position unavailable")
                return
            end

            local delta = lateral - neutralLateral
            local step = lateral - previousLateral
            local dt = math.max(now - previousSampleAt, 1 / 240)
            local velocity = step / dt
            previousSampleAt = now

            if phase == 0 then
                if math.abs(delta) >= initialTravelThreshold then
                    firstDirection = delta >= 0 and 1 or -1
                    firstLegTravel = math.abs(delta)
                    phase = 1
                end
            elseif phase == 1 then
                if math.abs(delta) > firstLegTravel then
                    firstLegTravel = math.abs(delta)
                    returnTravel = 0
                    reversalFrames = 0
                end

                if velocity * firstDirection < -0.01 then
                    reversalFrames = reversalFrames + 1
                    returnTravel = returnTravel + math.abs(step)
                    if reversalFrames >= Config.FIREFLY_ARM_REVERSAL_FRAMES then
                        phase = 2
                    end
                else
                    reversalFrames = 0
                    returnTravel = 0
                end
            elseif phase == 2 then
                local returnVelocity = -velocity * firstDirection
                if returnVelocity > 0.01 then
                    returnTravel = returnTravel + math.abs(step)
                    local returnRatio = firstLegTravel > 0 and returnTravel / firstLegTravel or 0
                    if returnTravel >= returnTravelThreshold
                        and returnRatio >= Config.FIREFLY_FIRST_JUMP_RETURN_RATIO then
                        beginTimedSequence()
                    end
                elseif velocity * firstDirection > 0.01 then
                    phase = 1
                    firstLegTravel = math.max(firstLegTravel, math.abs(delta))
                    returnTravel = 0
                    reversalFrames = 0
                end
            end

            previousLateral = lateral
            if not sequenceStarted then
                return
            end
        end

        confirmFirstTakeoff()
        if not firstJumpAirborne then
            if firstJumpRequestDeadline and now >= firstJumpRequestDeadline then
                finishAttempt("Firefly: first jump not detected")
                return
            end

            if humanoid.FloorMaterial ~= Enum.Material.Air
                and math.abs(rootPart.AssemblyLinearVelocity.Y) <= 1.5
                and now >= nextFirstJumpRetryAt then
                if not firstJumpRequestDeadline then
                    firstJumpRequestDeadline = now + 0.22
                end
                nextFirstJumpRetryAt = now + 0.045
                requestFirstJumpAgain()
            end
        end

        if firstJumpAirborne and isCharacterGrounded() then
            if handleLandedGroundPart(getGroundPart(), now) then
                return
            end
        end

        if not sequenceStarted then
            return
        end

        if landedOnLid and secondJumpRequested and not secondJumpDetected then
            if secondJumpRequestDeadline and now >= secondJumpRequestDeadline then
                finishAttempt("Firefly: second jump failed")
                return
            end

            local lid = fireflyDoubleJumpLid
            if now >= nextSecondJumpRetryAt
                and lid and lid.Parent == Workspace
                and humanoid.FloorMaterial ~= Enum.Material.Air
                and math.abs(rootPart.AssemblyLinearVelocity.Y) <= 1.5
                and getGroundPart(true) == lid then
                nextSecondJumpRetryAt = now + 0.06
                issueSecondJumpRequest()
            end
        end

        if movementWindowDeadline and now >= movementWindowDeadline then
            fireflyDiag.log("MOVE_WINDOW_EXPIRED", "movement deadline reached before/after lid jump request; lidLanded="
                .. tostring(landedOnLid) .. "; secondRequested=" .. tostring(secondJumpRequested)
                .. "; secondDetected=" .. tostring(secondJumpDetected))
            stopFireflyForwardMovement()
            pcall(function()
                humanoid:Move(Vector3.zero, false)
            end)
            movementWindowDeadline = nil
        end

        if inputWindowDeadline and now >= inputWindowDeadline and not movementWindowDeadline then
            if landedOnLid and secondJumpRequested and not secondJumpDetected then
                if secondJumpRequestDeadline and now >= secondJumpRequestDeadline then
                    finishAttempt("Firefly: second jump failed")
                    return
                end
            elseif sequenceResolutionDeadline and now >= sequenceResolutionDeadline then
                finishAttempt("Firefly: sequence timed out")
                return
            elseif not movementWindowStarted and sequenceStartedAt and now >= sequenceStartedAt + 1.25 then
                finishAttempt("Firefly: lid not detected")
                return
            elseif not firstJumpAirborne and firstJumpRequestDeadline and now >= firstJumpRequestDeadline then
                finishAttempt("Firefly: first jump not detected")
                return
            end
        end
    end)
    return true
end

local function armFireflyBounce(character, humanoid, rootPart)
    if not character or not humanoid or not rootPart then
        return
    end

    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end

    local startedAt = fireflyTimingStartedAt
    fireflyTimingActive = true
    fireflyTimingElapsed = nil

    local function finishTiming(instance)
        if not fireflyTimingActive then
            return
        end

        if not instance or instance.Name ~= "Handle2" or not instance:IsA("Part") or instance.Parent ~= Workspace then
            return
        end

        fireflyTimingElapsed = os.clock() - startedAt
        fireflyTimingActive = false

        if fireflyTimingChildConnection then
            fireflyTimingChildConnection:Disconnect()
            fireflyTimingChildConnection = nil
        end
        if fireflyTimingRenderConnection then
            fireflyTimingRenderConnection:Disconnect()
            fireflyTimingRenderConnection = nil
        end

        statusLabel.Text = string.format("Firefly lid opened: %.3fs", fireflyTimingElapsed)
    end

    fireflyTimingChildConnection = Workspace.ChildAdded:Connect(finishTiming)

    fireflyTimingRenderConnection = RunService.RenderStepped:Connect(function()
        if not character.Parent or not rootPart.Parent or humanoid.Health <= 0 then
            if fireflyTimingChildConnection then
                fireflyTimingChildConnection:Disconnect()
                fireflyTimingChildConnection = nil
            end
            if fireflyTimingRenderConnection then
                fireflyTimingRenderConnection:Disconnect()
                fireflyTimingRenderConnection = nil
            end
            fireflyTimingActive = false
            return
        end

        if fireflyTimingActive then
            statusLabel.Text = string.format("Opening Firefly: %.3fs", os.clock() - startedAt)
        end
    end)
end

local function armBombBounce(character, humanoid, rootPart, bombPart, targetPosition, bombTool, getObservedBomb)
    if not character or not humanoid or not rootPart then
        return
    end

    if savedBombSettings.BombStyle == "Blatant" and selectedBombType ~= "Firefly Jar" then
        local deadline = os.clock() + Config.BOMB_BOUNCE_TRACK_TIME
        local finished = false
        local jumpConnection

        local function finish()
            finished = true
            if jumpConnection then
                jumpConnection:Disconnect()
                jumpConnection = nil
            end
        end

        local function tryAirJump()
            if finished then return true end
            if fireflyDiag.stopped or character ~= LocalPlayer.Character
                or not character.Parent or not rootPart.Parent or not humanoid.Parent or humanoid.Health <= 0 then
                finish()
                return true
            end

            local velocity = rootPart.AssemblyLinearVelocity
            if velocity.Y > -Config.BOMB_LAUNCH_FALL_SPEED then
                return false
            end

            local jumpVelocity = humanoid.UseJumpPower and humanoid.JumpPower
                or math.sqrt(math.max(0, 2 * Workspace.Gravity * humanoid.JumpHeight))
            finish()
            pcall(function()
                humanoid.Jump = false
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
            rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, jumpVelocity), velocity.Z)
            statusLabel.Text = "Blatant: air jump"
            fireflyDiag.log("BLATANT_JUMP", string.format("impulse=%.2f; previousY=%.2f; independent of bomb contact",jumpVelocity,velocity.Y))
            return true
        end

        if tryAirJump() then return end
        jumpConnection = RunService.PostSimulation:Connect(function()
            if os.clock() >= deadline then
                finish()
                fireflyDiag.log("BLATANT_JUMP_END", "descent threshold not reached before timeout")
                return
            end
            tryAirJump()
        end)
        return
    end

    local hardDeadline = os.clock() + Config.BOMB_BOUNCE_TRACK_TIME
    local observedBomb = bombPart ~= nil and bombPart.Parent ~= nil
    local deadline = observedBomb and (os.clock() + Config.BOMB_BOUNCE_INPUT_HOLD_TIME) or hardDeadline
    local inputConnection
    local contactNudgeLogged = false
    local expectedJumpSpeed
    if humanoid.UseJumpPower then
        expectedJumpSpeed = humanoid.JumpPower
    else
        expectedJumpSpeed = math.sqrt(math.max(0, 2 * Workspace.Gravity * humanoid.JumpHeight))
    end
    local jumpConfirmationSpeed = math.max(0.5, expectedJumpSpeed * 0.5)
    fireflyDiag.log("NORMAL_JUMP_WINDOW", observedBomb and "bomb candidate already observed" or "holding input while awaiting replicated bomb; bounded to track timeout")

    local function cleanup()
        if inputConnection then
            inputConnection:Disconnect()
            inputConnection = nil
        end
        pcall(function()
            humanoid.Jump = false
        end)
    end

    inputConnection = RunService.RenderStepped:Connect(function()
        if not observedBomb and getObservedBomb then
            local candidate = getObservedBomb()
            if candidate and candidate.Parent then
                observedBomb = true
                deadline = math.min(hardDeadline, os.clock() + Config.BOMB_BOUNCE_INPUT_HOLD_TIME)
                fireflyDiag.log("NORMAL_BOMB_ARRIVED", "jump input window extended from actual client observation")
            end
        end
        if not character.Parent or not rootPart.Parent or humanoid.Health <= 0 or os.clock() >= deadline then
            fireflyDiag.log("NORMAL_JUMP_END", "input window closed; observed="..tostring(observedBomb))
            cleanup()
            return
        end
        local verticalSpeed = rootPart.AssemblyLinearVelocity.Y
        local currentState = humanoid:GetState()
        if currentState == Enum.HumanoidStateType.Jumping and verticalSpeed >= jumpConfirmationSpeed then
            fireflyDiag.log("NORMAL_JUMP_CONFIRMED", string.format("state=Jumping; vY=%.2f; expected=%.2f",
                verticalSpeed,expectedJumpSpeed))
            cleanup()
            return
        end
        if verticalSpeed > 1 and not contactNudgeLogged then
            contactNudgeLogged = true
            fireflyDiag.log("NORMAL_CONTACT_NUDGE", string.format("vY=%.2f; state=%s; input retained; confirmation threshold=%.2f",
                verticalSpeed,tostring(currentState),jumpConfirmationSpeed))
        end

        pcall(function()
            humanoid.Jump = true
        end)
    end)
end

lockBombActivation = function()
    if bombToolActivationLocked then
        return
    end

    local bombTool
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if selectedBombType == "Firefly Jar" then
        bombTool = findRealFireflyJar(LocalPlayer)
    else
        bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
    end
    if not bombTool then
        return
    end

    local ok = pcall(function()
        bombToolActivationOriginal = bombTool.ManualActivationOnly
        bombTool.ManualActivationOnly = true
    end)

    if ok then
        bombToolActivationLocked = true
        bombToolActivationReference = bombTool
    end
end

unlockBombActivation = function()
    if not bombToolActivationLocked then
        return
    end

    local bombTool = bombToolActivationReference
    pcall(function()
        if bombTool and bombTool.Parent then
            bombTool.ManualActivationOnly = bombToolActivationOriginal
        end
    end)

    bombToolActivationLocked = false
    bombToolActivationReference = nil
    bombToolActivationOriginal = nil
end

resetBombCooldown = function()
    bombCooldownGeneration = bombCooldownGeneration + 1
    isWaitingTimerBomb = false
    hasTriggeredBomb = false
    isActiveBomb = false
    isArmedBomb = false
    cancelFireflyDoubleJump()
    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end
    fireflyTimingActive = false
    fireflyTimingStartedAt = 0
    fireflyTimingElapsed = nil
    saveBombSettings()
    statusLabel.Text = "Ready"
    renderBombVisualState()
end

local function updatePendingBombVisual()
    if not bombButton then
        return
    end
    renderBombVisualState()
    statusLabel.Text = "Armed. Jump to launch. Tap again to cancel."
end

local function disconnectPendingBombWatchers()
    if pendingBombStateConnection then
        pendingBombStateConnection:Disconnect()
        pendingBombStateConnection = nil
    end
    if pendingBombHeartbeatConnection then
        pendingBombHeartbeatConnection:Disconnect()
        pendingBombHeartbeatConnection = nil
    end
end

local function finishBombCooldown()
    if isWaitingTimerBomb then
        if isActiveBomb or isArmedBomb then
            isActiveBomb = false
            isArmedBomb = false
            saveBombSettings()
            renderBombVisualState()
        end
        return
    end

    bombCooldownGeneration = bombCooldownGeneration + 1
    local generation = bombCooldownGeneration
    isWaitingTimerBomb = true
    isActiveBomb = false
    isArmedBomb = false
    local cooldown
    if selectedBombType == "Gold Bomb" then
        cooldown = Config.GOLD_COOLDOWN
    elseif selectedBombType == "Firefly Jar" then
        cooldown = Config.FIREFLY_COOLDOWN
    else
        cooldown = Config.NORMAL_COOLDOWN
    end
    local deadline = time() + cooldown
    saveBombSettings()

    statusLabel.Text = string.format("Cooldown: %.1fs", cooldown)
    renderBombVisualState()

    task.spawn(function()
        while isWaitingTimerBomb and generation == bombCooldownGeneration and time() < deadline do
            local remaining = math.max(0, deadline - time())
            if not noGuiTimerBomb then
                bombButton.Text = string.format("Wait (%.1fs)", remaining)
            else
                renderBombVisualState()
            end
            bombButton.TextColor3 = Color3.fromRGB(255, 70, 70)
            bombStroke.Color = Color3.fromRGB(255, 0, 0)
            if cooldownOverlay then
                cooldownOverlay.BackgroundTransparency = 0.70
            end
            if selectedBombType ~= "Firefly Jar" or not fireflyTimingActive then
                if selectedBombType == "Firefly Jar" and fireflyTimingElapsed then
                    statusLabel.Text = string.format("Lid opened: %.3fs | Cooldown: %.1fs", fireflyTimingElapsed, remaining)
                else
                    statusLabel.Text = string.format("Cooldown: %.1fs", remaining)
                end
            end
            task.wait(0.05)
        end

        if not isWaitingTimerBomb or generation ~= bombCooldownGeneration then
            return
        end

        isWaitingTimerBomb = false
        hasTriggeredBomb = false
        statusLabel.Text = "Ready"
        renderBombVisualState()
        saveBombSettings()
    end)
end

local function activateFireflyJar()
    if isWaitingTimerBomb then
        return false
    end

    local activationGeneration = bombCooldownGeneration
    local cooldownAnchor = os.clock()
    local player = LocalPlayer
    local character = player and player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return false
    end
    fireflyDiag.beginAttempt()
    fireflyDiag.log("ACTIVATION_BEGIN", string.format("state=%s; rig=%s; rootVy=%.2f; speed=%.2f; ping=%.0fms; root=(%.2f,%.2f,%.2f); velocity=(%.2f,%.2f,%.2f); input=(%.2f,%.2f); facing=(%.2f,%.2f)",
        tostring(humanoid:GetState()),tostring(humanoid.RigType),rootPart.AssemblyLinearVelocity.Y,
        humanoid.WalkSpeed,getBombPing(player)*1000,rootPart.Position.X,rootPart.Position.Y,rootPart.Position.Z,
        rootPart.AssemblyLinearVelocity.X,rootPart.AssemblyLinearVelocity.Y,rootPart.AssemblyLinearVelocity.Z,
        humanoid.MoveDirection.X,humanoid.MoveDirection.Z,rootPart.CFrame.LookVector.X,rootPart.CFrame.LookVector.Z))

    local bombTool = prepareRealFireflyJar(player)
    if not bombTool then
        statusLabel.Text = "Firefly Jar not found"
        fireflyDiag.log("ACTIVATION_FAILED", statusLabel.Text)
        return false
    end

    local backpack = player:FindFirstChild("Backpack")
    local fireflyEquipped = bombTool.Parent == character
    local fireflyEquippedConnection = nil
    local fireflyMouse = nil

    pcall(function()
        fireflyEquippedConnection = bombTool.Equipped:Connect(function(mouse)
            fireflyEquipped = true
            fireflyMouse = mouse
        end)
    end)

    if bombTool.Parent ~= character then
        if bombTool.Parent ~= backpack then
            if fireflyEquippedConnection then
                fireflyEquippedConnection:Disconnect()
            end
            statusLabel.Text = "Firefly Jar is not in Backpack"
            fireflyDiag.log("ACTIVATION_FAILED", statusLabel.Text)
            return false
        end

        pcall(function()
            humanoid:EquipTool(bombTool)
        end)

        local equipDeadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 1.50)
        while (bombTool.Parent ~= character or not fireflyEquipped)
            and os.clock() < equipDeadline do
            RunService.Heartbeat:Wait()
        end
    end

    if fireflyEquipped and not fireflyMouse then
        pcall(function()
            fireflyEquipped = false
            humanoid:UnequipTools()
        end)

        RunService.Heartbeat:Wait()

        if bombTool.Parent ~= character then
            pcall(function()
                humanoid:EquipTool(bombTool)
            end)
        end

        local reEquipDeadline = os.clock() + 1.50
        while (bombTool.Parent ~= character or not fireflyMouse)
            and os.clock() < reEquipDeadline do
            RunService.Heartbeat:Wait()
        end
        fireflyEquipped = bombTool.Parent == character
    end

    if fireflyEquipped and not fireflyMouse then
        pcall(function()
            fireflyMouse = player:GetMouse()
        end)
    end

    if fireflyEquippedConnection then
        fireflyEquippedConnection:Disconnect()
        fireflyEquippedConnection = nil
    end

    if bombTool.Parent ~= character or not fireflyEquipped then
        statusLabel.Text = "Firefly Jar could not be equipped"
        fireflyDiag.log("ACTIVATION_FAILED", statusLabel.Text)
        return false
    end

    lastKnownBombTool = bombTool

    task.wait(Config.FIREFLY_EQUIP_SETTLE_TIME)
    if activationGeneration ~= bombCooldownGeneration or player.Character ~= character
        or not character.Parent or humanoid.Health <= 0 then
        fireflyDiag.log("ACTIVATION_CANCELLED", "character or cooldown generation changed during equip")
        return false
    end

    local originalManualActivationOnly = nil
    pcall(function()
        originalManualActivationOnly = bombTool.ManualActivationOnly
        bombTool.ManualActivationOnly = false
    end)

    RunService.Heartbeat:Wait()

    pcall(function()
        bombTool:Deactivate()
    end)
    RunService.Heartbeat:Wait()

    local preActivationFireflyLids = snapshotExistingFireflyLids()
    local fireflyShoulder = findFireflyRightShoulder(character)
    local fireflyActivationState = { activated = false }
    local armed = armFireflyDoubleJump(
        character,
        humanoid,
        rootPart,
        fireflyShoulder,
        preActivationFireflyLids,
        fireflyActivationState
    )
    if not armed then
        pcall(function()
            if originalManualActivationOnly ~= nil then bombTool.ManualActivationOnly = originalManualActivationOnly end
        end)
        unlockBombActivation()
        fireflyDiag.log("ACTIVATION_FAILED", "arm sensor preflight failed; no activation input sent")
        return false
    end

    local activated = false
    local fireflyReleaseAnchor = nil
    local fireflyMousePressStarted = false
    local toolActivationObserved = false
    local toolActivationConnection = nil

    pcall(function()
        toolActivationConnection = bombTool.Activated:Connect(function()
            toolActivationObserved = true
            fireflyActivationState.activated = true
            fireflyDiag.log("TOOL_ACTIVATED", string.format("elapsed=%.3f; state=%s; rootVy=%.2f",
                os.clock()-cooldownAnchor,tostring(humanoid:GetState()),rootPart.AssemblyLinearVelocity.Y))
        end)
    end)

    local function waitForToolActivation(timeout)
        local deadline = os.clock() + timeout
        while not toolActivationObserved and os.clock() < deadline do
            RunService.Heartbeat:Wait()
        end
        return toolActivationObserved
    end

    local function releaseFireflyMousePress()
        if not fireflyMousePressStarted then
            return
        end
        pcall(function()
            if fireflyMouse and fireflyMouse.Button1Up and type(firesignal) == "function" then
                firesignal(fireflyMouse.Button1Up)
            end
        end)
        fireflyMousePressStarted = false
    end

    if fireflyMouse and fireflyMouse.Button1Down and type(firesignal) == "function" then
        fireflyDiag.log("ACTIVATION_PATH", "mouse firesignal")
        local pressSucceeded = pcall(function()
            fireflyReleaseAnchor = os.clock()
            fireflyMousePressStarted = true
            firesignal(fireflyMouse.Button1Down)
        end)
        if pressSucceeded then
            activated = waitForToolActivation(0.20)
        end
        if not activated then
            releaseFireflyMousePress()
        end
    end

    if not activated and fireflyMouse and fireflyMouse.Button1Down and type(getconnections) == "function" then
        fireflyDiag.log("ACTIVATION_PATH", "mouse callback fallback")
        local callSucceeded, invoked = pcall(function()
            fireflyReleaseAnchor = os.clock()
            local connections = getconnections(fireflyMouse.Button1Down)
            local called = false
            for _, connection in ipairs(connections) do
                if connection and connection.Function then
                    called = pcall(connection.Function) or called
                end
            end
            return called
        end)
        if callSucceeded and invoked then
            activated = waitForToolActivation(0.20)
        end
    end

    if not activated then
        fireflyDiag.log("ACTIVATION_PATH", "Tool:Activate fallback")
        local activateSucceeded = pcall(function()
            fireflyReleaseAnchor = os.clock()
            bombTool:Activate()
        end)
        if activateSucceeded then
            activated = waitForToolActivation(0.20)
        end
    end

    if toolActivationConnection then
        toolActivationConnection:Disconnect()
        toolActivationConnection = nil
    end
    fireflyDiag.log("ACTIVATION_RESULT", "Tool.Activated observed="..tostring(activated))

    if not activated then
        releaseFireflyMousePress()
    end

    if not activated then
        if fireflyTimingChildConnection then
            fireflyTimingChildConnection:Disconnect()
            fireflyTimingChildConnection = nil
        end
        if fireflyTimingRenderConnection then
            fireflyTimingRenderConnection:Disconnect()
            fireflyTimingRenderConnection = nil
        end
        fireflyTimingActive = false
        fireflyTimingElapsed = nil
        cancelFireflyDoubleJump()
        statusLabel.Text = "Firefly Jar activation failed"

        pcall(function()
            if originalManualActivationOnly ~= nil then
                bombTool.ManualActivationOnly = originalManualActivationOnly
            end
        end)
        unlockBombActivation()
        return false
    end

    pcall(function()
        if originalManualActivationOnly ~= nil then
            bombTool.ManualActivationOnly = originalManualActivationOnly
        end
    end)

    unlockBombActivation()

    task.spawn(function()
        local releaseAnchor = fireflyReleaseAnchor or os.clock()
        local releaseDelay = releaseAnchor + Config.FIREFLY_RELEASE_DELAY - os.clock()
        if releaseDelay > 0 then
            task.wait(releaseDelay)
        end

        releaseFireflyMousePress()
        pcall(function()
            bombTool:Deactivate()
            if originalManualActivationOnly ~= nil then
                bombTool.ManualActivationOnly = originalManualActivationOnly
            else
                bombTool.ManualActivationOnly = false
            end
        end)

        pcall(function()
            if bombTool.Parent == character then
                humanoid:UnequipTools()
            end
            RunService.Heartbeat:Wait()
            if bombTool.Parent == character then
                local currentBackpack = player:FindFirstChild("Backpack")
                if currentBackpack then
                    bombTool.Parent = currentBackpack
                end
            end
        end)
    end)

    local cooldownDelay = cooldownAnchor + Config.FIREFLY_COOLDOWN_START_DELAY - os.clock()
    if cooldownDelay > 0 then
        task.wait(cooldownDelay)
    end

    if activationGeneration ~= bombCooldownGeneration
        or not character.Parent
        or humanoid.Health <= 0
        or player.Character ~= character then
        return false
    end

    finishBombCooldown()

    return true
end

local function launchPendingBombJump()
    if not pendingBombJump or pendingBombLaunchInProgress then
        return
    end

    local launchGeneration = pendingBombSequenceGeneration
    local player = LocalPlayer
    local character = pendingBombCharacter
    local humanoid = pendingBombHumanoid
    local rootPart = pendingBombRootPart
    local bombTool = pendingBombTool
    local wasEquipped = pendingBombWasEquipped
    local wasToggle = pendingBombWasToggle
    local freefallFastPath = pendingBombStartedInFreefall

    if not player or not character or not humanoid or not rootPart or not bombTool then
        return
    end

    if humanoid.Health <= 0 or not character.Parent then
        cancelPendingBombJump()
        return
    end

    if not BombStyleRuntime.isDescending(humanoid, rootPart) then
        return
    end

    if bombTool.Parent ~= character then
        return
    end

    if freefallFastPath then
        pendingBombLaunchInProgress = true
        if not pendingBombJump
            or pendingBombSequenceGeneration ~= launchGeneration
            or pendingBombCharacter ~= character
            or pendingBombTool ~= bombTool then
            pendingBombLaunchInProgress = false
            return
        end
        if not character.Parent or humanoid.Health <= 0 or player.Character ~= character then
            pendingBombLaunchInProgress = false
            cancelPendingBombJump()
            return
        end
        if bombTool.Parent ~= character then
            pendingBombLaunchInProgress = false
            return
        end

        pendingBombLaunchInProgress = false
    end

    disconnectPendingBombWatchers()

    pendingBombJump = false
    pendingBombTool = nil
    pendingBombCharacter = nil
    pendingBombHumanoid = nil
    pendingBombRootPart = nil
    pendingBombWasToggle = false
    pendingBombEquipDeadline = 0
    pendingBombLaunchWindowReached = false
    pendingBombLaunchWaitDeadline = nil
    pendingBombStartedInFreefall = false

    local targetPosition = nil
    local targetPart = nil
    local bombPart = nil
    local bombTrace = nil
    local descendantConnection
    local detectionDeadline = os.clock() + 0.18
    local launchConfirmed = false
    local throwOrigin = rootPart.Position
    local rightHand = character:FindFirstChild("RightHand")
        or character:FindFirstChild("Right Arm")
        or character:FindFirstChild("RightLowerArm")
        or character:FindFirstChild("RightUpperArm")
    if rightHand and rightHand:IsA("BasePart") then
        throwOrigin = rightHand.Position
    end

    local existingBombParts = {}
    local newBombCandidates = {}
    local bombDetectionScheduled = false
    local launchOverlapParams = OverlapParams.new()
    launchOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
    launchOverlapParams.FilterDescendantsInstances = {character, bombTool}
    launchOverlapParams.MaxParts = 128

    for _, instance in ipairs(Workspace:GetPartBoundsInRadius(throwOrigin, 24, launchOverlapParams)) do
        existingBombParts[instance] = true
    end

    local function isPlausibleThrownBombPart(instance, metadata)
        if not instance or not instance:IsA("BasePart") or not instance.Parent then
            return false
        end
        if instance:IsDescendantOf(character) or instance:IsDescendantOf(bombTool) then
            return false
        end
        if existingBombParts[instance] or not metadata then
            return false
        end

        local largestDimension = math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
        if largestDimension < 0.16 or largestDimension > 9 then
            return false
        end

        if instance.Anchored then
            return false
        end

        local namedCandidate = isBombCandidate(instance, character, bombTool)
        local originDistance = (instance.Position - throwOrigin).Magnitude
        local targetDistance = targetPosition and (instance.Position - targetPosition).Magnitude or math.huge

        if namedCandidate then
            return metadata.originDistance <= 24 or metadata.targetDistance <= 12
        end

        if not (instance.CanCollide or instance.CanTouch or instance.CanQuery) then
            return false
        end

        return metadata.originDistance <= 13 and (originDistance <= 16 or targetDistance <= 8)
    end

    local function findNewlySpawnedBombPart()
        local bestPart = nil
        local bestScore = math.huge

        local function consider(instance)
            local metadata = newBombCandidates[instance]
            if not isPlausibleThrownBombPart(instance, metadata) then
                return
            end

            local originDistance = (instance.Position - throwOrigin).Magnitude
            local targetDistance = targetPosition and (instance.Position - targetPosition).Magnitude or originDistance
            local largestDimension = math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
            local agePenalty = metadata and math.max(0, os.clock() - metadata.createdAt) * 3 or 2
            local nameBonus = isBombCandidate(instance, character, bombTool) and -100 or 0
            local collisionBonus = instance.CanCollide and -8 or 0
            local sizeBonus = -math.min(largestDimension, 3) * 0.2
            local score = nameBonus + targetDistance + originDistance * 0.12 + agePenalty + collisionBonus + sizeBonus

            if score < bestScore then
                bestScore = score
                bestPart = instance
            end
        end

        for instance in pairs(newBombCandidates) do
            consider(instance)
        end

        for _, instance in ipairs(Workspace:GetPartBoundsInRadius(throwOrigin, 24, launchOverlapParams)) do
            consider(instance)
        end

        if targetPosition then
            for _, instance in ipairs(Workspace:GetPartBoundsInRadius(targetPosition, 12, launchOverlapParams)) do
                consider(instance)
            end
        end

        return bestPart
    end

    local function selectNewlySpawnedBombPart()
        if bombPart and bombPart.Parent then
            return true
        end

        local candidate = findNewlySpawnedBombPart()
        if not candidate then
            return false
        end

        bombPart = candidate
        BombStyleRuntime.traceBomb(bombTrace, candidate, character, rootPart)
        return true
    end

    local function cleanupDetection()
        if descendantConnection then
            descendantConnection:Disconnect()
            descendantConnection = nil
        end
    end

    descendantConnection = Workspace.DescendantAdded:Connect(function(instance)
        if not instance:IsA("BasePart") or existingBombParts[instance] then
            return
        end
        if instance:IsDescendantOf(character) or instance:IsDescendantOf(bombTool) then
            return
        end

        local namedCandidate = isBombCandidate(instance, character, bombTool)
        local largestDimension = math.max(instance.Size.X, instance.Size.Y, instance.Size.Z)
        if largestDimension < 0.16 or largestDimension > 9 then
            return
        end
        if not namedCandidate and not (instance.CanCollide or instance.CanTouch or instance.CanQuery) then
            return
        end

        local distanceFromThrowOrigin = (instance.Position - throwOrigin).Magnitude
        local distanceFromTarget = targetPosition and (instance.Position - targetPosition).Magnitude or math.huge
        if namedCandidate then
            if distanceFromThrowOrigin > 24 and distanceFromTarget > 12 then
                return
            end
        elseif distanceFromThrowOrigin > 13 and distanceFromTarget > 8 then
            return
        end

        newBombCandidates[instance] = {
            createdAt = os.clock(),
            named = namedCandidate,
            originDistance = distanceFromThrowOrigin,
            targetDistance = distanceFromTarget,
        }
        if bombDetectionScheduled then
            return
        end
        bombDetectionScheduled = true

        task.delay(0.02, function()
            bombDetectionScheduled = false
            if not bombPart then
                selectNewlySpawnedBombPart()
            end
        end)
    end)

    local activationConnection = bombTool.Activated:Connect(function()
        launchConfirmed = true
    end)

    local directRemoteLaunch, remoteTargetPosition = fireBombRemote(
        bombTool,
        character,
        rootPart,
        humanoid,
        player,
        freefallFastPath
    )

    if directRemoteLaunch then
        targetPosition = remoteTargetPosition
        bombTrace = BombStyleRuntime.latestTrace
    else
        targetPosition, _, targetPart = getPredictedBombTarget(
            character,
            humanoid,
            rootPart,
            bombTool,
            player
        )
    end

    if directRemoteLaunch then
        selectNewlySpawnedBombPart()
    end

    if not targetPosition then
        cleanupDetection()
        if activationConnection then
            activationConnection:Disconnect()
        end
        pcall(function()
            bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
        end)
        pendingBombManualActivationOriginal = nil
        unlockBombActivation()
        if not wasEquipped and bombTool.Parent == character then
            pcall(function()
                humanoid:UnequipTools()
            end)
        end
        if not wasToggle then
            updatePendingBombVisual()
        end
        return
    end

    if wasToggle then
        saveBombSettings()
    end

    local mouse
    local previousTargetFilter

    if not directRemoteLaunch then
        local camera = Workspace.CurrentCamera
        if not camera then
            cleanupDetection()
            if activationConnection then
                activationConnection:Disconnect()
            end
            pcall(function()
                bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
            end)
            pendingBombManualActivationOriginal = nil
            unlockBombActivation()
            if not wasEquipped and bombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
            return
        end

        local screenPosition, inputCamera = getVirtualBombInput(camera, targetPosition)
        if not screenPosition or not inputCamera then
            cleanupDetection()
            if activationConnection then
                activationConnection:Disconnect()
            end
            pcall(function()
                bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
            end)
            pendingBombManualActivationOriginal = nil
            unlockBombActivation()
            if not wasEquipped and bombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
            return
        end

        setBombMouseOverride(inputCamera, screenPosition, targetPosition, targetPart)
        mouse = player:GetMouse()
        previousTargetFilter = mouse.TargetFilter
        mouse.TargetFilter = character

        pcall(function()
            bombTool.ManualActivationOnly = false
        end)

        local activated = performBombActivationInput(
            screenPosition,
            inputCamera,
            function()
                return launchConfirmed
            end
        )

        if not launchConfirmed and type(firesignal) == "function" then
            pcall(function()
                firesignal(bombTool.Activated)
            end)
            activated = true
            RunService.Heartbeat:Wait()
        end

        if not launchConfirmed and activated then
            pcall(function()
                fireBombActivatedConnections(bombTool)
            end)
            RunService.Heartbeat:Wait()
        end

        pcall(function()
            bombTool:Deactivate()
        end)
    end

    if directRemoteLaunch and not freefallFastPath then
        task.wait(0.05)
    end

    pcall(function()
        bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
    end)
    pendingBombManualActivationOriginal = nil

    if mouse then
        pcall(function()
            if mouse.TargetFilter == character then
                mouse.TargetFilter = previousTargetFilter
            end
        end)
    end

    unlockBombActivation()

    task.spawn(function()
        RunService.Heartbeat:Wait()
        pcall(function()
            if bombTool.Parent == character then
                humanoid:UnequipTools()
            end
            RunService.Heartbeat:Wait()
            if bombTool.Parent == character then
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    bombTool.Parent = backpack
                end
            end
        end)
    end)

    if activationConnection then
        activationConnection:Disconnect()
    end

    if not bombPart then
        bombPart = findNearbyBombPart(character, bombTool, targetPosition)
        if not bombPart then
            bombPart = findNearbyBombPart(character, bombTool, throwOrigin)
        end
    end

    BombStyleRuntime.traceBomb(bombTrace, bombPart, character, rootPart)
    armBombBounce(character, humanoid, rootPart, bombPart, targetPosition, bombTool, function()
        return bombPart
    end)

    task.spawn(function()
        local placementDeadline = os.clock() + Config.BOMB_BOUNCE_TRACK_TIME

        while os.clock() < placementDeadline do
            if fireflyDiag.stopped or character ~= player.Character or not character.Parent or humanoid.Health <= 0 then
                break
            end
            if not bombPart then
                selectNewlySpawnedBombPart()
            end
            if not bombPart then
                bombPart = findNearbyBombPart(character, bombTool, targetPosition)
                if not bombPart then
                    bombPart = findNearbyBombPart(character, bombTool, throwOrigin)
                end
            end

            if bombPart and bombPart.Parent then
                BombStyleRuntime.traceBomb(bombTrace, bombPart, character, rootPart)
                if not directRemoteLaunch then
                    placeBombAtTarget(bombPart, character, targetPosition)
                end
                break
            end

            RunService.Heartbeat:Wait()
        end
        cleanupDetection()
        if bombTrace and not bombTrace.observed and not fireflyDiag.stopped then
            fireflyDiag.log("NO_BOMB_OBSERVED", "no candidate found during tracking; not proof of a rejected throw or an underground bomb")
        end
    end)

    if mouse then
        task.delay(0.08, clearBombMouseOverride)
    end

    finishBombCooldown()
end

cancelPendingBombJump = function()
    if not pendingBombJump then
        local preTool = preEquippedBombTool
        local preWasEquipped = preEquippedBombWasEquipped
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        releaseScriptEquippedBomb(preTool, character, humanoid, preWasEquipped)
        clearPreEquippedBomb()
        return
    end

    pendingBombSequenceGeneration += 1
    local bombTool = pendingBombTool
    local character = pendingBombCharacter
    local humanoid = pendingBombHumanoid
    local wasEquipped = pendingBombWasEquipped
    local wasToggle = pendingBombWasToggle

    disconnectPendingBombWatchers()

    pendingBombJump = false
    pendingBombTool = nil
    pendingBombCharacter = nil
    pendingBombHumanoid = nil
    pendingBombRootPart = nil
    pendingBombWasToggle = false
    pendingBombEquipDeadline = 0
    pendingBombLaunchWindowReached = false
    pendingBombLaunchWaitDeadline = nil
    pendingBombStartedInFreefall = false

    pcall(function()
        if bombTool and bombTool.Parent then
            bombTool.ManualActivationOnly = pendingBombManualActivationOriginal
        end
    end)

    pendingBombManualActivationOriginal = nil
    unlockBombActivation()

    if fireflyTimingChildConnection then
        fireflyTimingChildConnection:Disconnect()
        fireflyTimingChildConnection = nil
    end
    if fireflyTimingRenderConnection then
        fireflyTimingRenderConnection:Disconnect()
        fireflyTimingRenderConnection = nil
    end
    fireflyTimingActive = false
    fireflyTimingStartedAt = 0
    fireflyTimingElapsed = nil
    cancelFireflyDoubleJump()

    releaseScriptEquippedBomb(bombTool, character, humanoid, wasEquipped)

    renderBombVisualState()
    statusLabel.Text = "Bomb Jump cancelled"
end

isBombJumpGrounded = function(character, humanoid, rootPart)
    if not character or not humanoid or not rootPart then
        return false
    end

    local state = humanoid:GetState()

    if state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Climbing
        or state == Enum.HumanoidStateType.Swimming
        or state == Enum.HumanoidStateType.Seated
        or state == Enum.HumanoidStateType.PlatformStanding
        or state == Enum.HumanoidStateType.Dead
    then
        return false
    end

    if humanoid.FloorMaterial ~= Enum.Material.Air then
        return true
    end

    local footCenter = getFootData(character, rootPart)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.IgnoreWater = false

    local result = Workspace:Raycast(
        footCenter + Vector3.new(0, 0.25, 0),
        Vector3.new(0, -1.75, 0),
        raycastParams
    )

    return result ~= nil
end


local function isBombLaunchMoment(humanoid, rootPart)
    return BombStyleRuntime.isDescending(humanoid, rootPart)
end

local function beginPendingBombJump(isToggleMode, bombTool, character, humanoid, rootPart, wasEquipped, originalManualActivationOnly, showArmed, startedInFreefall)
    if pendingBombJump then
        return false
    end

    pendingBombSequenceGeneration += 1
    pendingBombTool = bombTool
    pendingBombCharacter = character
    pendingBombHumanoid = humanoid
    pendingBombRootPart = rootPart
    pendingBombWasEquipped = wasEquipped
    pendingBombManualActivationOriginal = originalManualActivationOnly
    pendingBombWasToggle = isToggleMode
    pendingBombEquipDeadline = os.clock() + math.max(5.0, Config.BOMB_EQUIP_TIMEOUT * 12)
    pendingBombLaunchWaitDeadline = nil
    pendingBombStartedInFreefall = startedInFreefall == true
        and BombStyleRuntime.usesInstantFreefallLaunch()
    pendingBombLaunchWindowReached = pendingBombStartedInFreefall
        or isBombLaunchMoment(humanoid, rootPart)
    pendingBombJump = true

    pcall(function()
        bombTool.ManualActivationOnly = true
    end)

    pendingBombStateConnection = humanoid.StateChanged:Connect(function(_, newState)
        if not pendingBombJump then
            return
        end

        if (newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.FallingDown)
            and isBombLaunchMoment(humanoid, rootPart) then
            pendingBombLaunchWindowReached = true
            task.defer(function()
                local canLaunch = selectedBombType == "Firefly Jar" or bombTool:FindFirstChild("Remote")
                if pendingBombJump and bombTool.Parent == character and canLaunch
                    and isBombLaunchMoment(humanoid, rootPart)
                    and (not pendingBombStartedInFreefall or pendingBombEquipDeadline <= 0) then
                    launchPendingBombJump()
                end
            end)
        end
    end)

    pendingBombHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if not pendingBombJump then
            return
        end

        if not humanoid.Parent or humanoid.Health <= 0 or not character.Parent then
            cancelPendingBombJump()
            return
        end

        local launchMoment = isBombLaunchMoment(humanoid, rootPart)
        local groundedNow = isBombJumpGrounded(character, humanoid, rootPart)

        if launchMoment then
            pendingBombLaunchWindowReached = true
        elseif pendingBombLaunchWindowReached and groundedNow then
            if pendingBombStartedInFreefall then
                cancelPendingBombJump()
                statusLabel.Text = "Freefall launch window ended before equip"
                return
            end
            pendingBombLaunchWindowReached = false
        end

        if bombTool.Parent ~= character
            and pendingBombEquipDeadline > 0
            and os.clock() >= pendingBombEquipDeadline then
            cancelPendingBombJump()
            hasTriggeredBomb = false
            statusLabel.Text = "Bomb equip timed out; ready to retry"
            renderBombVisualState()
            return
        end

        if bombTool.Parent ~= character and launchMoment and not pendingBombStartedInFreefall then
            local wasOutOfHand = true

            pcall(function()
                humanoid:EquipTool(bombTool)
            end)

            if bombTool.Parent ~= character then
                pcall(function()
                    bombTool.Parent = character
                end)
            end

            if wasOutOfHand and bombTool.Parent == character then
                pcall(function()
                    bombTool.ManualActivationOnly = true
                end)
            end
        end

        local canLaunch = selectedBombType == "Firefly Jar" or bombTool:FindFirstChild("Remote")
        if bombTool.Parent == character and pendingBombLaunchWindowReached and not canLaunch then
            if not pendingBombLaunchWaitDeadline then
                pendingBombLaunchWaitDeadline = os.clock() + 0.75
            elseif os.clock() >= pendingBombLaunchWaitDeadline then
                cancelPendingBombJump()
                hasTriggeredBomb = false
                statusLabel.Text = "Bomb remote unavailable; ready to retry"
                renderBombVisualState()
                return
            end
        else
            pendingBombLaunchWaitDeadline = nil
        end

        if bombTool.Parent == character
            and pendingBombLaunchWindowReached
            and canLaunch
            and (not pendingBombStartedInFreefall or pendingBombEquipDeadline <= 0) then
            launchPendingBombJump()
        end
    end)

    if showArmed or bombUseMode == "Armed To Use Bomb" then
        updatePendingBombVisual()
    else
        renderBombVisualState()
    end

    return true
end

local function quickUseBomb(isToggleMode, armOnly)
    if selectedBombType == "Firefly Jar" then
        return activateFireflyJar()
    end

    if isWaitingTimerBomb then
        return
    end

    if pendingBombJump then
        return
    end

    local player = LocalPlayer
    local character = player and player.Character
    if not character then
        return
    end

    if isToggleMode and not isActiveBomb then
        local preTool = preEquippedBombTool
        local preWasEquipped = preEquippedBombWasEquipped
        local preHumanoid = character:FindFirstChildOfClass("Humanoid")
        releaseScriptEquippedBomb(preTool, character, preHumanoid, preWasEquipped)
        clearPreEquippedBomb()
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        return
    end

    local requestedDuringFreefall = BombStyleRuntime.usesInstantFreefallLaunch()
        and BombStyleRuntime.isDescending(humanoid, rootPart)

    if armOnly and not isBombJumpGrounded(character, humanoid, rootPart) then
        return
    end

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        return
    end

    if lastKnownBombTool and lastKnownBombTool.Parent ~= character and lastKnownBombTool.Parent ~= backpack then
        lastKnownBombTool = nil
    end

    local bombTool
    if selectedBombType == "Firefly Jar" then
        bombTool = prepareRealFireflyJar(player)
    else
        bombTool = bombToolActivationReference
            or preEquippedBombTool
            or lastKnownBombTool
            or findSelectedBombTool(character)
            or findSelectedBombTool(backpack)

        if bombTool and bombTool.Parent ~= character and bombTool.Parent ~= backpack then
            bombTool = findSelectedBombTool(character)
                or findSelectedBombTool(backpack)
        end
    end

    if not bombTool and selectedBombType ~= "Firefly Jar" then
        local remote = resolveToyEvent()
        if remote then
            pcall(function()
                remote:InvokeServer(getBombToolName())
            end)

            local findTimeout = requestedDuringFreefall and math.max(Config.BOMB_EQUIP_TIMEOUT, 0.75) or Config.BOMB_EQUIP_TIMEOUT
            local findDeadline = os.clock() + findTimeout
            while not bombTool and os.clock() < findDeadline do
                bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
                if bombTool then
                    break
                end
                RunService.Heartbeat:Wait()
            end
        end
    end

    if not bombTool then
        statusLabel.Text = "Bomb tool not found: " .. getBombToolName()
        clearPreEquippedBomb()
        return
    end

    lastKnownBombTool = bombTool

    local wasEquipped = bombTool.Parent == character
    local originalManualActivationOnly = nil

    pcall(function()
        originalManualActivationOnly = bombTool.ManualActivationOnly
    end)

    if not beginPendingBombJump(
        isToggleMode,
        bombTool,
        character,
        humanoid,
        rootPart,
        wasEquipped,
        originalManualActivationOnly,
        armOnly,
        requestedDuringFreefall
    ) then
        clearPreEquippedBomb()
        return
    end

    if wasEquipped then
        clearPreEquippedBomb()
        pendingBombEquipDeadline = 0
    end

    if not wasEquipped then
        local equipDeadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 2.50)
        while bombTool.Parent ~= character and os.clock() < equipDeadline and pendingBombJump do
            pcall(function()
                humanoid:EquipTool(bombTool)
            end)
            if bombTool.Parent ~= character then
                pcall(function()
                    bombTool.Parent = character
                end)
            end
            RunService.Heartbeat:Wait()
        end

        if not pendingBombJump then
            if bombTool.Parent == character then
                pcall(function()
                    humanoid:UnequipTools()
                end)
            end
            return
        end

        if bombTool.Parent == character then
            pendingBombEquipDeadline = 0
            clearPreEquippedBomb()
            if not pendingBombStartedInFreefall then
                RunService.RenderStepped:Wait()
            end
        end
    end

    if bombTool.Parent ~= character and pendingBombJump then
        pcall(function()
            humanoid:EquipTool(bombTool)
        end)
        if bombTool.Parent ~= character then
            pcall(function()
                bombTool.Parent = character
            end)
        end
        RunService.Heartbeat:Wait()
        if bombTool.Parent == character then
            pendingBombEquipDeadline = 0
            clearPreEquippedBomb()
        end
    end

    if bombTool.Parent ~= character then
        cancelPendingBombJump()
        return
    end

    if humanoid.Health <= 0 or not character.Parent then
        cancelPendingBombJump()
        return
    end

    if isToggleMode and bombUseMode == "Toggle To Use Bomb" and not isActiveBomb then
        cancelPendingBombJump()
        return
    end

    if pendingBombJump
        and pendingBombLaunchWindowReached
        and bombTool.Parent == character then
        local currentState = humanoid:GetState()
        if currentState == Enum.HumanoidStateType.Freefall
            or currentState == Enum.HumanoidStateType.FallingDown then
            launchPendingBombJump()
        end
    end
end

local function setToggleReady(value, armedMode)
    if armedMode then
        isArmedBomb = value
    else
        isActiveBomb = value
    end

    saveBombSettings()
    renderBombVisualState()

    if not value or selectedBombType == "Firefly Jar" then
        return
    end

    local requestedMode = armedMode and "Armed To Use Bomb" or "Toggle To Use Bomb"
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not character or not humanoid or humanoid.Health <= 0 or not backpack then
        return
    end

    task.spawn(function()
        local function modeStillReady()
            return character == LocalPlayer.Character
                and not isWaitingTimerBomb
                and selectedBombType ~= "Firefly Jar"
                and bombUseMode == requestedMode
                and ((armedMode and isArmedBomb) or (not armedMode and isActiveBomb))
                and humanoid.Parent ~= nil
                and humanoid.Health > 0
        end

        if not modeStillReady() then
            return
        end

        local bombTool = bombToolActivationReference
            or preEquippedBombTool
            or lastKnownBombTool
            or findSelectedBombTool(character)
            or findSelectedBombTool(backpack)

        if bombTool and bombTool.Parent ~= character and bombTool.Parent ~= backpack then
            bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
        end

        if not bombTool then
            local remote = resolveToyEvent()
            if remote then
                pcall(function()
                    remote:InvokeServer(getBombToolName())
                end)
            end
        end

        local findDeadline = os.clock() + math.max(Config.BOMB_EQUIP_TIMEOUT, 0.50)
        while not bombTool and os.clock() < findDeadline do
            if not modeStillReady() then
                return
            end
            bombTool = findSelectedBombTool(character) or findSelectedBombTool(backpack)
            if not bombTool then
                RunService.Heartbeat:Wait()
            end
        end

        if not bombTool then
            if modeStillReady() then
                statusLabel.Text = "Bomb tool not found: " .. getBombToolName()
            end
            return
        end

        if not modeStillReady() then
            return
        end

        lastKnownBombTool = bombTool
        if preEquippedBombTool ~= bombTool then
            preEquippedBombWasEquipped = bombTool.Parent == character
            preEquippedBombTool = bombTool
        end

        if bombTool.Parent ~= character then
            requestFastBombEquip(humanoid, character, bombTool)
        end
    end)
end

bombButton.Activated:Connect(function()
    if movedBomb or bombPressWasDragged or isWaitingTimerBomb then
        return
    end

    if bombUseMode == "Toggle To Use Bomb" and isActiveBomb then
        setToggleReady(false)
        hasTriggeredBomb = false
        cancelPendingBombJump()
        clearPreEquippedBomb()
        unlockBombActivation()
        bombActionInProgress = false
        return
    end

    if bombUseMode == "Armed To Use Bomb" and (isArmedBomb or pendingBombJump) then
        isArmedBomb = false
        cancelPendingBombJump()
        clearPreEquippedBomb()
        unlockBombActivation()
        renderBombVisualState()
        return
    end

    if bombActionInProgress then
        return
    end

    if selectedBombType == "Firefly Jar" then
        bombActionInProgress = true
        task.defer(function()
            local ok, err = pcall(function()
                activateFireflyJar()
            end)
            if not ok then
                fireflyDiag.log("ACTIVATION_ERROR", tostring(err))
                cancelFireflyDoubleJump()
                unlockBombActivation()
                statusLabel.Text = "Firefly: activation error; copy Jar diagnostics"
            end
            bombActionInProgress = false
            bombPressReleased = true
            bombPressInput = nil
            bombPressWasDragged = false
        end)
        return
    end

    if bombUseMode == "Toggle To Use Bomb" then
        setToggleReady(true)
        hasTriggeredBomb = false
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local grounded = character and humanoid and rootPart and isBombJumpGrounded(character, humanoid, rootPart)

    if bombUseMode == "Click To Use Bomb" and grounded == true then
        statusLabel.Text = "Jump first to use Bomb Jump"
        return
    end

    local armOnly = bombUseMode == "Armed To Use Bomb" and grounded == true

    if armOnly then
        setToggleReady(true, true)
        hasTriggeredBomb = false
        return
    end

    bombActionInProgress = true
    task.defer(function()
        pcall(function()
            quickUseBomb(false, false)
        end)
        bombActionInProgress = false
        bombPressReleased = true
        bombPressInput = nil
        bombPressWasDragged = false
    end)
end)
local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local freefallAutoConnection

    humanoid.Died:Connect(function()
        if freefallAutoConnection then
            freefallAutoConnection:Disconnect()
            freefallAutoConnection = nil
        end
        isArmedBomb = false
        cancelPendingBombJump()
        unlockBombActivation()
        resetBombCooldown()
        bombActionInProgress = false
        bombPressReleased = true
        bombPressInput = nil
        bombPressWasDragged = false
    end)

    humanoid.StateChanged:Connect(function(_, state)
        local persistentMode = bombUseMode == "Toggle To Use Bomb"
            or (bombUseMode == "Armed To Use Bomb" and isArmedBomb)

        if state == Enum.HumanoidStateType.Landed and persistentMode and not isWaitingTimerBomb then
            hasTriggeredBomb = false
        end

        if not persistentMode then
            return
        end

        local modeActive = (bombUseMode == "Toggle To Use Bomb" and isActiveBomb)
            or (bombUseMode == "Armed To Use Bomb" and isArmedBomb)

        if not modeActive or hasTriggeredBomb or isWaitingTimerBomb then
            return
        end

        local freefallLaunch = BombStyleRuntime.usesInstantFreefallLaunch()
            and (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown)
            and BombStyleRuntime.isDescending(humanoid, character:FindFirstChild("HumanoidRootPart"))
        if state == Enum.HumanoidStateType.Jumping or freefallLaunch then
            if not bombActionInProgress and not pendingBombJump then
                hasTriggeredBomb = true
                bombActionInProgress = true

                task.defer(function()
                    pcall(function()
                        quickUseBomb(bombUseMode == "Toggle To Use Bomb", false)
                    end)

                    bombActionInProgress = false
                end)
            end
        end
    end)

    freefallAutoConnection = RunService.Heartbeat:Connect(function()
        if character ~= LocalPlayer.Character or not character.Parent or not humanoid.Parent or humanoid.Health <= 0 then
            if freefallAutoConnection then
                freefallAutoConnection:Disconnect()
                freefallAutoConnection = nil
            end
            return
        end

        if not BombStyleRuntime.usesInstantFreefallLaunch() then
            return
        end

        local modeActive = (bombUseMode == "Toggle To Use Bomb" and isActiveBomb)
            or (bombUseMode == "Armed To Use Bomb" and isArmedBomb)
        if not modeActive or hasTriggeredBomb or isWaitingTimerBomb or bombActionInProgress or pendingBombJump then
            return
        end

        local state = humanoid:GetState()
        if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.FallingDown then
            return
        end

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart or not BombStyleRuntime.isDescending(humanoid, rootPart) then
            return
        end

        hasTriggeredBomb = true
        bombActionInProgress = true
        task.defer(function()
            pcall(function()
                quickUseBomb(bombUseMode == "Toggle To Use Bomb", false)
            end)
            bombActionInProgress = false
        end)
    end)
end

if LocalPlayer.Character then
    task.defer(setupCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(character)
    resetBombCooldown()
    setupCharacter(character)
end)

statusLabel.Text = resolveToyEvent() and "Ready" or "Ready: ReplicateToy unavailable"
if fireflyDiag.initError or fireflyDiag.guiError then
    statusLabel.Text = "Controller ready; Jar diagnostics error: " .. tostring(fireflyDiag.initError or fireflyDiag.guiError)
end
updateBombVisuals()
