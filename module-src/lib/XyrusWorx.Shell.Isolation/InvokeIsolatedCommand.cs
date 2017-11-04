using System.Management.Automation;
using System.Management.Automation.Runspaces;
using JetBrains.Annotations;

namespace XyrusWorx.Shell.Isolation {
	[PublicAPI]
	[Cmdlet(VerbsLifecycle.Invoke, "Isolated")]
	public class InvokeIsolatedCommand : Cmdlet
	{
		[Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
		public string Command { get; set; }
		
		[Parameter]
		public object Context { get; set; }
		
		[Parameter]
		public IsolationScope Scope { get; set; }
		
		protected override void ProcessRecord()
		{
			var ownScope = Scope == null;
			var scope = Scope ?? new IsolationScope(this, Runspace.DefaultRunspace);
			
			try
			{
				var context = new PSObject(Context ?? new object());
				scope.Execute(this, new object[]{context}, Command);
			}
			finally
			{
				if (ownScope)
				{
					scope.Exit(this);
				}
			}
		}
	}
}