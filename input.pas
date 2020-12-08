var
  LInput: TInput;
begin
  LInput.Itype := INPUT_MOUSE;
  LInput.mi.dwFlags := MOUSEEVENTF_MOVE;
  LInput.mi.mouseData := 0;
  LInput.mi.dx := 0;
  LInput.mi.dy := 0;
  LInput.mi.time := 0;
  LInput.mi.dwExtraInfo := 0;
  SendInput(1, LInput, SizeOf(LInput));
