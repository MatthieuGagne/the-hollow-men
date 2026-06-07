#nullable disable

using Godot;
using YarnSpinnerGodot;

namespace TheHollowMen;

[GlobalClass]
public partial class GameStateVariableStorage : VariableStorageBehaviour
{
    private Node GameState => GetNode<Node>("/root/GameState");

    private static string NormalizeKey(string variableName) =>
        variableName.StartsWith("$") ? variableName[1..] : variableName;

    public override bool TryGetValue<T>(string variableName, out T result)
    {
        var key = NormalizeKey(variableName);
        if (!Contains(key))
        {
            result = default;
            return false;
        }
        var raw = GameState.Call("get_flag", key, new Variant());
        if (raw.Obj is T typed)
        {
            result = typed;
            return true;
        }
        GD.PushError($"GameStateVariableStorage: type mismatch for '{key}' — expected {typeof(T).Name}");
        result = default;
        return false;
    }

    public override void SetValue(string variableName, bool boolValue) =>
        GameState.Call("set_flag", NormalizeKey(variableName), boolValue);

    public override void SetValue(string variableName, float floatValue) =>
        GameState.Call("set_flag", NormalizeKey(variableName), floatValue);

    public override void SetValue(string variableName, string stringValue) =>
        GameState.Call("set_flag", NormalizeKey(variableName), stringValue);

    public override void Clear() { }

    public override bool Contains(string variableName) =>
        GameState.Call("has_flag", NormalizeKey(variableName)).AsBool();

    public override void SetAllVariables(
        System.Collections.Generic.Dictionary<string, float> floats,
        System.Collections.Generic.Dictionary<string, string> strings,
        System.Collections.Generic.Dictionary<string, bool> bools,
        bool clear = true)
    {
        foreach (var kv in floats) SetValue(kv.Key, kv.Value);
        foreach (var kv in strings) SetValue(kv.Key, kv.Value);
        foreach (var kv in bools) SetValue(kv.Key, kv.Value);
    }

    public override (
        System.Collections.Generic.Dictionary<string, float>,
        System.Collections.Generic.Dictionary<string, string>,
        System.Collections.Generic.Dictionary<string, bool>) GetAllVariables()
    {
        return (new(), new(), new());
    }

    [YarnCommand("show_narration")]
    public void ShowNarration(string text)
    {
        GetNode<Node>("/root/DialogueManager").Call("show_narration", text);
    }
}
