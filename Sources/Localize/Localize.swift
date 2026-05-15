import ArgumentParser


struct Localize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "localize",
        abstract: "Updating or templating iOS Strings",
        subcommands: [Updating.self, Template.self])
}
