using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageToolsFolder : PackageFolder
	{
		public sealed override StringKey Key => "tools";
	}
}