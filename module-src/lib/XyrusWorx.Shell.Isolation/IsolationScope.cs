using System;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Management.Automation.Runspaces;
using JetBrains.Annotations;

namespace XyrusWorx.Shell.Isolation {
	[PublicAPI]
	public class IsolationScope
	{
		private PSHost mHost;
		private Runspace mRunspace;
		private PowerShell mShell;

		internal IsolationScope([NotNull] Cmdlet cmdlet, [NotNull] Runspace hostingRunspace, bool createNewState = false)
		{
			if (hostingRunspace == null)
			{
				throw new ArgumentNullException(nameof(hostingRunspace));
			}
			
			Id = Guid.NewGuid();
			mHost = (cmdlet ?? throw new ArgumentNullException(nameof(cmdlet))).CommandRuntime.Host;
			
			var sessionState = createNewState 
				? InitialSessionState.CreateDefault() 
				: hostingRunspace.InitialSessionState.Clone();

			mRunspace = RunspaceFactory.CreateRunspace(mHost, sessionState);
			
			mShell = PowerShell.Create(sessionState);
			mShell.Runspace = mRunspace;
			
			mRunspace.Open();
			
			cmdlet.WriteDebug($"Opening temporary shell {Id:B}");
		}

		public Guid Id { get; }

		internal void Execute(Cmdlet cmdlet, object[] input, string script)
		{
			if (mHost == null)
			{
				throw new Exception("The shell has been closed.");
			}

			cmdlet.WriteDebug($"Executing command in temporary shell {Id:B}: {script}");
			mShell.AddCommand("Foreach-Object")
				.AddParameter("Process", ScriptBlock.Create(script))
				.AddParameter("InformationAction", "Continue")
				.AddParameter("Verbose");

			var result = mShell.Invoke(input.ToArray());
						
			foreach (var error in mShell.Streams.Error.ReadAll())
			{
				cmdlet.WriteError(error);
			}

			foreach (var item in result)
			{
				cmdlet.WriteObject(item);
			}
		}
		internal void Exit(Cmdlet cmdlet)
		{
			cmdlet.WriteDebug($"Closing temporary shell {Id:B}");
			
			mRunspace?.Close();
			mRunspace?.Dispose();
			mShell?.Dispose();
			
			mShell = null;
			mRunspace = null;
			mHost = null;
		}
	}

}
