using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using Minimatch;
using XyrusWorx.Diagnostics;
using XyrusWorx.IO;
using XyrusWorx.Runtime;

namespace XyrusWorx.Management.Pacman.Controllers
{
	class MainController : ConsoleApplication
	{
		private readonly ProjectController mProjects;

		public MainController()
		{
			ServiceLocator.Default.Register<ConsoleApplication>(this);
			mProjects = new ProjectController(this);
		}

		public string MinimatchPattern { get; private set; }
		public string TargetDirectory { get; private set; }

		protected override IResult InitializeOverride()
		{
			ShowBanner = false;

			Log.LinkedDispatchers.Add(new DelegateLogWriter(WriteMessage));

			CommandLine.RegisterAlias("target", "o");
			CommandLine.RegisterAlias("verbosity", "v");

			Log.Verbosity = CommandLine.Read("verbosity").TryDeserialize<LogVerbosity>();

#if (DEBUG)
			if (!Debugger.IsAttached)
			{
				Interactive = false;
			}
#else
			Interactive = false;
#endif

			var args = Environment.GetCommandLineArgs().Skip(1).ToArray();
			var lastArg = args.LastOrDefault();

			if (!string.IsNullOrWhiteSpace(lastArg))
			{
				if (args.Length > 1)
				{
					var secondLastArg = args[args.Length - 2];
					if (!(secondLastArg?.StartsWith("-") ?? false))
					{
						MinimatchPattern = lastArg;
					}
				}
				else
				{
					MinimatchPattern = lastArg;
				}
			}

			if (string.IsNullOrWhiteSpace(MinimatchPattern))
			{
				return Result.CreateError("Usage: pacman [options] <filter>");
			}

			TargetDirectory = CommandLine.Read("target");

			if (!string.IsNullOrWhiteSpace(TargetDirectory))
			{
				try
				{
					Directory.CreateDirectory(TargetDirectory);
				}
				catch (Exception exception)
				{
					return Result.CreateError($"Failed to access target directory \"{TargetDirectory}\": {exception.Message}");
				}

				Log.WriteInformation($"Selecting output path: {TargetDirectory}");
			}
			else
			{
				TargetDirectory = null;
			}

			return base.InitializeOverride();
		}
		protected override IResult Execute(CancellationToken cancellationToken)
		{
			var count = 0;
			var matcher = new Minimatcher(MinimatchPattern, new Options { IgnoreCase = true });
			var baseDirectory = new DirectoryInfo(Environment.CurrentDirectory);
			var targetStore = string.IsNullOrWhiteSpace(TargetDirectory) ? null : new FileSystemStore(TargetDirectory);

			foreach (var file in baseDirectory.GetFiles("*.*", SearchOption.AllDirectories))
			{
				var relativePath = file.FullName.Substring(baseDirectory.FullName.Length + 1);
				if (matcher.IsMatch(relativePath))
				{
					mProjects.Export(file.FullName, targetStore);
					count++;
				}
			}

			if (count == 0)
			{
				Log.WriteWarning($"No files matched the given pattern: {MinimatchPattern}");
			}

			return Result.Success;
		}
		protected override void CleanupOverride()
		{
			if (ExecutionResult.HasError)
			{
				Log.WriteError(ExecutionResult.ErrorDescription);
			}

			base.CleanupOverride();
		}

		private static void WriteMessage(LogMessage message)
		{
			var tag = "info";

			var color = Console.ForegroundColor;
			var stream = Console.Out;

			if (message.Class == LogMessageClass.Warning)
			{
				Console.ForegroundColor = ConsoleColor.Yellow;
				tag = "warn";
			}
			else if (message.Class == LogMessageClass.Error)
			{
				Console.ForegroundColor = ConsoleColor.Red;
				stream = Console.Error;
				tag = "error";
			}
			else if (message.Class == LogMessageClass.Debug)
			{
				Console.ForegroundColor = ConsoleColor.DarkGray;
				tag = "debug";
			}

			// ReSharper disable once UnusedVariable
			var paddedTag = $"[ {tag.PadLeft(5, ' ')} ]";
			var text = $"{paddedTag} {message.Text}".WordWrap(Console.WindowWidth - 5, new string(' ', paddedTag.Length + 1), "");
			//var text = $"{message.Text}".WordWrap(Console.WindowWidth - 5, "", "");

			stream.WriteLine(text);

			Console.ForegroundColor = color;
		}
	}
}
