
Hook.Patch("ChatState_MultiPlayerList", "Barotrauma.TabMenu", "CreateMultiPlayerList", function(instance, ptable)
    ptable.PreventExecution = true
end, Hook.HookMethodType.After)

Hook.Patch("ChatState_DrawFront", "Barotrauma.Character", "DrawFront", function(instance, ptable)
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Hook.Patch("ChatState_SpeechBubble", "Barotrauma.Character", "ShowSpeechBubble", function(instance, ptable)
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Hook.Patch("ChatState_KillChar", "Barotrauma.CrewManager", "KillCharacter", function(instance, ptable)
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)

Hook.Patch("ChatState_RemoveChar", "Barotrauma.CrewManager", "RemoveCharacter", function(instance, ptable)
    ptable.PreventExecution = true
end, Hook.HookMethodType.Before)
