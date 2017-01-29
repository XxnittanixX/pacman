using JetBrains.Annotations;
using XyrusWorx.Diagnostics;
using XyrusWorx.IO;
using XyrusWorx.Management.ObjectModel;

namespace XyrusWorx.Management.Pacman
{
	[PublicAPI]
	public abstract class PackagingStategy
	{
		public abstract bool IsApplicable([NotNull] BinaryContainer container, ILogWriter log = null);

		[NotNull]
		public abstract PackageModel Process([NotNull] BinaryContainer container, ILogWriter log = null);
	}
}