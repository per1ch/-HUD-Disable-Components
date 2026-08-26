-- Hook.RemovePatch("ChatState_MultiPlayerList", "Barotrauma.TabMenu", "CreateMultiPlayerList", Hook.HookMethodType.After)

-- Hook.RemovePatch("ChatState_DrawFront", "Barotrauma.Character", "DrawFront", Hook.HookMethodType.Before)

-- Hook.RemovePatch("ChatState_SpeechBubble", "Barotrauma.Character", "ShowSpeechBubble", Hook.HookMethodType.Before)

-- Hook.RemovePatch("ChatState_KillChar", "Barotrauma.CrewManager", "KillCharacter", Hook.HookMethodType.Before)

-- Hook.RemovePatch("ChatState_RemoveChar", "Barotrauma.CrewManager", "RemoveCharacter", Hook.HookMethodType.Before)

-- Первым аргументом идет ВАШ уникальный идентификатор патча

Hook.Patch("ChatState_MultiPlayerList", "Barotrauma.TabMenu", "CreateMultiPlayerList", function(instance, ptable)
end, Hook.HookMethodType.After)

Hook.Patch("ChatState_DrawFront", "Barotrauma.Character", "DrawFront", function(instance, ptable)
end, Hook.HookMethodType.Before)

Hook.Patch("ChatState_SpeechBubble", "Barotrauma.Character", "ShowSpeechBubble", function(instance, ptable)
end, Hook.HookMethodType.Before)

Hook.Patch("ChatState_KillChar", "Barotrauma.CrewManager", "KillCharacter", function(instance, ptable)
end, Hook.HookMethodType.Before)

Hook.Patch("ChatState_RemoveChar", "Barotrauma.CrewManager", "RemoveCharacter", function(instance, ptable)
end, Hook.HookMethodType.Before)
