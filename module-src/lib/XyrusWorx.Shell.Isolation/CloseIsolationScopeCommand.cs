using System.Management.Automation;
using JetBrains.Annotations;

namespace XyrusWorx.Shell.Isolation {
	[PublicAPI]
	[Cmdlet(VerbsCommon.Close, "IsolationScope")]
	public class CloseIsolationScopeCommand : Cmdlet
	{
		[Parameter(Position = 0, ValueFromPipeline = true, Mandatory = true)]
		public IsolationScope Scope { get; set; }
		
		protected override void ProcessRecord()
		{
			Scope?.Exit(this);
		}
	}
}