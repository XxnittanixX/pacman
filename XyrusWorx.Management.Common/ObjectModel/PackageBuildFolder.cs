using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageBuildFolder : PackageFolder
	{
		public sealed override StringKey Key => "build";
	}
}