using System.Management.Automation;
using System.Management.Automation.Runspaces;
using JetBrains.Annotations;

namespace XyrusWorx {
	[PublicAPI]
	[Cmdlet(VerbsCommon.Open, "IsolationScope")]
	public class OpenIsolationScopeCommand : Cmdlet
	{
		[Parameter]
		public SwitchParameter Stateless { get; set; }
		
		protected override void ProcessRecord()
		{
			WriteObject(new IsolationScope(this, Runspace.DefaultRunspace, Stateless.IsPresent));
		}
	}
}