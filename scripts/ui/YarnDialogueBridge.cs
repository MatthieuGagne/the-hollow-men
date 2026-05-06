using System.Collections.Generic;
using System.Threading;
using Godot;
using YarnSpinnerGodot;

[GlobalClass]
public partial class YarnDialogueBridge : Node, DialoguePresenterBase
{
    [Signal] public delegate void LineDeliveredEventHandler(string speaker, string text);
    [Signal] public delegate void OptionsPresentedEventHandler(string[] options);
    [Signal] public delegate void DialogueCompleteEventHandler();

    [Export] public DialogueRunner Runner { get; set; }

    public List<IActionMarkupHandler> ActionMarkupHandlers { get; } = new();

    private bool _lineAdvanced;
    private int _pendingOptionIndex = -1;
    private DialogueOption[]? _pendingOptions;

    public async YarnTask RunLineAsync(LocalizedLine line, LineCancellationToken token)
    {
        _lineAdvanced = false;
        EmitSignal(SignalName.LineDelivered, line.CharacterName ?? "", line.TextWithoutCharacterName.Text);
        await YarnTask.WaitUntil(() => _lineAdvanced || token.IsNextLineRequested);
        _lineAdvanced = false;
    }

    public async YarnTask<DialogueOption?> RunOptionsAsync(DialogueOption[] dialogueOptions, CancellationToken cancellationToken)
    {
        _pendingOptions = dialogueOptions;
        _pendingOptionIndex = -1;
        var texts = new string[dialogueOptions.Length];
        for (int i = 0; i < dialogueOptions.Length; i++)
            texts[i] = dialogueOptions[i].Line.TextWithoutCharacterName.Text;
        EmitSignal(SignalName.OptionsPresented, texts);
        await YarnTask.WaitUntil(() => _pendingOptionIndex >= 0 || cancellationToken.IsCancellationRequested);
        if (cancellationToken.IsCancellationRequested || _pendingOptionIndex < 0 || _pendingOptionIndex >= dialogueOptions.Length)
            return null;
        return dialogueOptions[_pendingOptionIndex];
    }

    public YarnTask OnDialogueCompleteAsync()
    {
        EmitSignal(SignalName.DialogueComplete);
        return YarnTask.CompletedTask;
    }

    public void ContinueLine()
    {
        _lineAdvanced = true;
    }

    public void SelectOption(int index)
    {
        _pendingOptionIndex = index;
    }

    public void StartDialogue(string nodeId)
    {
        Runner?.StartDialogue(nodeId);
    }
}
